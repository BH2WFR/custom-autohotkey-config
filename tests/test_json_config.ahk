#Requires AutoHotkey v2.0.19+
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk

try {
    ConfigTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}

class ConfigTests {
    static Count := 0
    static Loaded := 0
    static Saved := 0
    static Reset := 0

    class Options {
        enabled := 1
        names := ["default"]
    }

    class Settings extends Config.IConfig {
        condaEnv := "base"
        f1Alias := 0
        options := ConfigTests.Options()
        folders := Map("first", Map("path", "C:\默认", "keep", 1))

        CheckValid() => this.condaEnv == "" ? "condaEnv 不能为空" : ""
        LoadCallback() => ConfigTests.Loaded++
        SaveCallback() => ConfigTests.Saved++
        ResetCallback() => ConfigTests.Reset++
    }

    static Assert(condition, message) {
        this.Count++
        if !condition
            throw Error(message)
    }

    static Throws(callback, message) {
        try callback()
        catch as err {
            if err is UnsetError
                throw err
            return this.Assert(true, message)
        }
        this.Assert(false, message)
    }

    static Run() {
        this.Directory := A_ScriptDir "\..\tmp\json_config_" A_Now "_" DllCall("GetCurrentProcessId")
        DirCreate(this.Directory)
        this.JsonRoundTrip()
        this.InvalidJson()
        this.Configuration()
        this.InvalidConfiguration()
        if A_Args.Length
            this.PythonInterop(A_Args[1])
        FileAppend("PASS: " this.Count " assertions`nFixtures: " this.Directory "`n", "*", "UTF-8")
    }

    static JsonRoundTrip() {
        value := Map(
            "text", '中文 한국어 😀 "引号" \ 路径' "`n`t`r",
            "numeric_string", "001",
            "integer", -42,
            "float", 1.25,
            "array", [Map("nested", "值"), [], Map()],
            "url", "https://example.com/a/b"
        )
        text := JsonGo.Stringify(value, , 4)
        restored := JsonGo.Parse(text)
        this.Assert(restored["text"] == value["text"], "Unicode、路径和控制字符往返")
        this.Assert(Type(restored["numeric_string"]) == "String", "数字字符串类型")
        this.Assert(restored["numeric_string"] == "001", "数字字符串内容")
        this.Assert(restored["integer"] == -42 && restored["float"] == 1.25, "数值往返")
        this.Assert(restored["array"][1]["nested"] == "值", "嵌套 Map/Array")
        this.Assert(restored["array"][2].Length == 0 && restored["array"][3].Count == 0, "空容器")
        this.Assert(InStr(text, "https://example.com/a/b"), "URL 不转义斜杠")
        this.Assert(JsonGo.Parse('"\\u4e2d"') == "\u4e2d", "保留字面的 Unicode 转义")
        this.Assert(JsonGo.Parse('"\u4e2d\u6587"') == "中文", "Unicode 转义解码")
        this.Assert(JsonGo.Parse('"\ud83d\ude00"') == "😀", "UTF-16 代理对")
        this.Assert(JsonGo.Parse("true") == 1 && JsonGo.Parse("false") == 0, "布尔值沿用 1/0")
        this.Assert(JsonGo.Parse("null") == "", "null 沿用空字符串")
        Config.SaveJson(value, this.Directory "\roundtrip.json")
        this.Assert(Config.LoadJson(this.Directory "\roundtrip.json")["text"] == value["text"], "UTF-8 文件往返")
    }

    static InvalidJson() {
        for text in ['{"broken":', '{"a":1,}', '[1,]', '01', '--1', '1,', 'true,', '"bad\q"', "", '{"a":"raw' "`n" 'newline"}']
            this.Throws(ObjBindMethod(JsonGo, "Parse", text), "应拒绝无效 JSON：" text)
    }

    static Configuration() {
        manager := Config.Manager("settings.json", this.Directory)
        settings := manager.Register(this.Settings(), "Main")
        this.Throws(() => manager.Register(this.Settings(), "Main"), "拒绝重复注册")
        this.Throws(() => manager.SaveAll(), "加载前不覆盖配置")
        manager.LoadAll()
        this.Assert(this.Loaded == 1, "首次加载回调")
        this.Assert(settings.condaEnv == "base", "缺少文件时保留默认值")
        this.Assert(manager.SaveAll(), "首次保存创建文件")
        this.Assert(!manager.SaveAll(), "配置不变时不写盘")

        Config.SaveJson(Map(
            "Main", Map("condaEnv", "tools", "f1Alias", 1,
                "options", Map("names", ["一", "二"], "future", 7),
                "folders", Map("first", Map("added", 9)),
                "unknown", "保留"),
            "Future", Map("enabled", 1)
        ), manager.Path)
        manager.LoadAll()
        this.Assert(settings.condaEnv == "tools" && settings.f1Alias == 1, "加载已保存字段")
        this.Assert(settings.options.enabled == 1 && settings.options.names.Length == 2, "嵌套默认值和数组替换")
        this.Assert(settings.folders["first"]["keep"] == 1 && settings.folders["first"]["added"] == 9, "嵌套 Map 合并")
        this.Assert(!settings.HasOwnProp("unknown"), "未知字段不注入实例")
        settings.condaEnv := "analysis"
        manager.SaveAll()
        stored := Config.LoadJson(manager.Path)
        this.Assert(stored["Main"]["condaEnv"] == "analysis", "修改持久化")
        this.Assert(stored["Main"]["unknown"] == "保留" && stored["Future"]["enabled"] == 1, "保留未知配置")
        this.Assert(stored["Main"]["options"]["future"] == 7, "保留嵌套未知配置")
        this.Assert(!FileExist(manager.Path ".tmp"), "保存完成后无临时文件")
        settings.folders["first"].Delete("added")
        manager.SaveAll()
        this.Assert(!Config.LoadJson(manager.Path)["Main"]["folders"]["first"].Has("added"), "Map 删除项持久化")

        second := Config.Manager("settings.json", this.Directory)
        secondSettings := second.Register(this.Settings(), "Main")
        second.LoadAll()
        this.Assert(secondSettings.condaEnv == "analysis", "独立 Manager 重载")
        this.Assert(!second.SaveAll(), "重载后无变化不写盘")
        manager.ResetAll()
        this.Assert(settings.condaEnv == "base" && settings.options.names[1] == "default", "重置默认字段")
        this.Assert(!settings.folders["first"].Has("added"), "重置 Map 移除新增项")
        this.Assert(this.Reset == 1, "重置回调")
        settings.options.names.Push("changed")
        manager.ResetAll()
        this.Assert(settings.options.names.Length == 1, "默认值快照不共享可变对象")
        this.Assert(Config.LoadJson(manager.Path)["Main"]["condaEnv"] == "analysis", "重置不自动写盘")
        manager.SaveAll()
        this.Assert(Config.LoadJson(manager.Path)["Main"]["condaEnv"] == "base", "显式保存重置结果")
        second.LoadAll()
        this.Assert(!secondSettings.folders["first"].Has("added"), "保存重置后不恢复旧 Map 项")
        settings.condaEnv := "changed"
        Config.SaveJson(Map("Main", Map("f1Alias", 1)), manager.Path)
        manager.LoadAll()
        this.Assert(settings.condaEnv == "base", "重新加载缺少字段时恢复默认值")
        this.Assert(this.Saved > 0, "保存回调")
    }

    static InvalidConfiguration() {
        path := this.Directory "\invalid.json"
        file := FileOpen(path, "w", "UTF-8-RAW")
        file.Write('{"Main":')
        file.Close()
        manager := Config.Manager("invalid.json", this.Directory)
        manager.Register(this.Settings(), "Main")
        this.Throws(() => manager.LoadAll(), "损坏文件报错")
        this.Throws(() => manager.SaveAll(), "加载失败后禁止覆盖原文件")
        this.Assert(FileRead(path, "UTF-8") == '{"Main":', "损坏文件原样保留")
        Config.SaveJson([], path)
        this.Throws(() => manager.LoadAll(), "配置顶层必须是对象")
        Config.SaveJson(Map("Main", Map("options", [])), path)
        this.Throws(() => manager.LoadAll(), "嵌套类型不匹配报错")
        Config.SaveJson(Map("Main", Map("condaEnv", "")), path)
        this.Throws(() => manager.LoadAll(), "配置校验报错")
    }

    static PythonInterop(path) {
        data := Config.LoadJson(path)
        this.Assert(data["text"] == '中文 한국어 😀 "引号" \ 路径' "`n`t`r", "读取 Python JSON 的 Unicode 和转义")
        this.Assert(data["literals"][1] == 1 && data["literals"][2] == 0 && data["literals"][3] == "", "读取 Python 布尔值和 null")
        Config.SaveJson(data, path ".roundtrip.json")
    }
}
