; 从 AHK-SysUtil2 移植；配置类注册、对象转换和 JSON 文件读写。
class Config {
    class IConfig {
        CheckValid() => ""
        LoadCallback() {
        }
        SaveCallback() {
        }
        ResetCallback() {
        }
    }

    ; 每个 Manager 管理一个 JSON 文件，配置对象按名称保存为顶层分组。
    class Manager {
        __New(filename, directory) {
            this.Path := directory "\" filename
            this._registered := Map()
            this._defaults := Map()
            this._data := Map()
            this._savedText := ""
            this._loaded := false
        }

        Register(instance, name := Type(instance)) {
            if !(instance is Config.IConfig)
                throw TypeError("配置类必须继承 Config.IConfig。")
            if this._registered.Has(name)
                throw ValueError("配置名称重复：" name)
            this._registered[name] := instance
            this._defaults[name] := Config.ObjectToPlainData(instance)
            return instance
        }

        LoadAll() {
            exists := FileExist(this.Path)
            data := exists ? Config.LoadJson(this.Path) : Map()
            if !(data is Map)
                throw TypeError("配置文件的顶层必须是 JSON 对象。")
            previous := Map()
            for name, instance in this._registered
                previous[name] := Config.ObjectToPlainData(instance)
            try {
                for name, instance in this._registered {
                    Config.LoadObjectFromPlainData(instance, this._defaults[name], false)
                    if data.Has(name)
                        Config.LoadObjectFromPlainData(instance, data[name])
                    this._CheckValid(instance, name)
                }
                for name, instance in this._registered
                    instance.LoadCallback()
            } catch as err {
                for name, instance in this._registered
                    Config.LoadObjectFromPlainData(instance, previous[name], false)
                throw err
            }
            this._data := data
            this._savedText := exists ? JsonGo.Stringify(data, , 4) : ""
            this._loaded := true
        }

        ; 返回是否实际写入；未改变的配置不重复写盘。
        SaveAll() {
            if !this._loaded
                throw Error("保存配置前须成功调用 LoadAll()。")
            data := Config.ObjectToPlainData(this._data)
            for name, instance in this._registered {
                instance.SaveCallback()
                this._CheckValid(instance, name)
                if !data.Has(name)
                    data[name] := Map()
                Config._UpdatePlainData(data[name], instance)
            }
            text := JsonGo.Stringify(data, , 4)
            if text == this._savedText
                return false
            Config._WriteJson(this.Path, text)
            this._data := data
            this._savedText := text
            return true
        }

        ; 恢复注册时的默认值；由调用方决定何时 SaveAll()。
        ResetAll() {
            for name, instance in this._registered {
                Config.LoadObjectFromPlainData(instance, this._defaults[name], false)
                instance.ResetCallback()
                this._data[name] := Config.ObjectToPlainData(instance)
            }
        }

        CheckAllValid() {
            for name, instance in this._registered
                this._CheckValid(instance, name)
        }

        _CheckValid(instance, name) {
            message := instance.CheckValid()
            if message != ""
                throw ValueError(name ": " message)
        }
    }

    ; 只转换实例自身的数据属性，跳过函数；Map、Array 递归复制。
    static ObjectToPlainData(value) {
        if value is Array {
            result := []
            for item in value
                result.Push(this.ObjectToPlainData(item))
            return result
        }
        if value is Map {
            result := Map()
            for key, item in value
                result[key] := this.ObjectToPlainData(item)
            return result
        }
        if IsObject(value) {
            result := Map()
            for key, item in value.OwnProps() {
                if !(item is Func)
                    result[key] := this.ObjectToPlainData(item)
            }
            return result
        }
        return value
    }

    ; 类实例仅加载已声明的属性；Map 合并，Array 替换。
    static LoadObjectFromPlainData(target, data, mergeMaps := true) {
        if target is Array {
            if !(data is Array)
                throw TypeError("数组配置必须对应 JSON 数组。")
            target.Length := 0
            for item in data
                target.Push(this.ObjectToPlainData(item))
            return
        }
        if !(data is Map)
            throw TypeError("对象配置必须对应 JSON 对象。")
        if target is Map {
            if !mergeMaps
                target.Clear()
            for key, value in data {
                if target.Has(key) && target[key] is Map && value is Map
                    this.LoadObjectFromPlainData(target[key], value, mergeMaps)
                else
                    target[key] := this.ObjectToPlainData(value)
            }
            return
        }
        for key, value in data {
            if !target.HasOwnProp(key) || target.%key% is Func
                continue
            if IsObject(target.%key%)
                this.LoadObjectFromPlainData(target.%key%, value, mergeMaps)
            else if IsObject(value)
                throw TypeError("标量配置不能加载对象或数组：" key)
            else
                target.%key% := value
        }
    }

    static LoadJson(path) => JsonGo.Parse(FileRead(path, "UTF-8"))

    ; 类的未知字段保留；已声明的 Map/Array 整体写回，使删除项也能持久化。
    static _UpdatePlainData(data, instance) {
        for key, value in instance.OwnProps() {
            if value is Func
                continue
            if IsObject(value) && !(value is Map) && !(value is Array) {
                if !data.Has(key) || !(data[key] is Map)
                    data[key] := Map()
                this._UpdatePlainData(data[key], value)
            } else
                data[key] := this.ObjectToPlainData(value)
        }
    }

    static SaveJson(value, path) {
        text := JsonGo.Stringify(this.ObjectToPlainData(value), , 4)
        this._WriteJson(path, text)
        return path
    }

    ; 先完成序列化和临时文件写入，再替换目标文件。
    static _WriteJson(path, text) {
        SplitPath(path, , &directory)
        if directory != ""
            DirCreate(directory)
        temporary := path ".tmp"
        file := FileOpen(temporary, "w", "UTF-8-RAW")
        try file.Write(text "`n")
        finally file.Close()
        FileMove(temporary, path, true)
    }
}
