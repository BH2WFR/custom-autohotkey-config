; 每个 Map 声明一个层；未声明的层不匹配，不向其他层降级。
class HotkeyRegistry {
    __New(matcher := unset) {
        this.Bindings := Map()
        this.Matcher := IsSet(matcher) ? matcher : ObjBindMethod(this, "MatchWindow")
    }

    Layers(key, layerMaps*) => this._Layers("", key, "layers", layerMaps*)
    Continuous(key, layerMaps*) => this._Layers("", key, "continuous", layerMaps*)
    Pass(key, callback) => this._Pass("", key, callback)
    App(winTitle) => HotkeyRegistry.Scope(this, winTitle)

    class Scope {
        __New(registry, winTitle) {
            this.Registry := registry
            this.WinTitle := winTitle
        }
        Layers(key, layerMaps*) {
            this.Registry._Layers(this.WinTitle, key, "layers", layerMaps*)
            return this
        }
        Pass(key, callback) {
            this.Registry._Pass(this.WinTitle, key, callback)
            return this
        }
    }

    _Layers(scope, key, mode, layerMaps*) {
        if !layerMaps.Length
            throw ValueError("Layers 至少需要一个层。")
        binding := this._Binding(scope, key, mode)
        for entry in layerMaps {
            if !(entry is Map) || entry.Count != 1
                throw ValueError("每层使用一个 Map(layer, callback)。")
            for layer, callback in entry {
                if !(layer is Integer) || layer < 1 || layer > 4
                    throw ValueError("层号必须为 1～4。")
                if !HasMethod(callback, "Call")
                    throw TypeError("热键动作必须可以调用。")
                if binding.Actions.Has(layer)
                    throw ValueError("重复注册：" key "，层 " layer)
                binding.Actions[layer] := callback
            }
        }
        return this
    }

    _Pass(scope, key, callback) {
        if !HasMethod(callback, "Call")
            throw TypeError("热键动作必须可以调用。")
        binding := this._Binding(scope, key, "pass")
        if binding.Actions.Has(0)
            throw ValueError("重复注册穿透热键：" key)
        binding.Actions[0] := callback
        return this
    }

    _Binding(scope, key, mode) {
        key := GetKeyName(key)
        if !this.Bindings.Has(key)
            this.Bindings[key] := []
        for binding in this.Bindings[key] {
            if binding.Scope == scope {
                if binding.Mode != mode
                    throw ValueError("同一应用中的同一按键不能混合穿透和分层绑定。")
                return binding
            }
        }
        binding := {Scope: scope, Mode: mode, Actions: Map()}
        this.Bindings[key].Push(binding)
        return binding
    }

    HasAppRules(key) {
        for binding in this.Bindings[key] {
            if binding.Scope != ""
                return true
        }
        return false
    }

    Resolve(key, layer, hwnd := 0) {
        if !this.Bindings.Has(key)
            return false
        fallback := false
        for binding in this.Bindings[key] {
            if binding.Scope == ""
                fallback := binding
            else if this.Matcher.Call(binding.Scope, hwnd)
                return this._Select(binding, layer)
        }
        return fallback ? this._Select(fallback, layer) : false
    }

    _Select(binding, layer) {
        index := binding.Mode == "pass" ? 0 : layer
        return binding.Actions.Has(index)
            ? {Mode: binding.Mode, Callback: binding.Actions[index]}
            : false
    }

    MatchWindow(winTitle, hwnd) => hwnd && WinExist(winTitle " ahk_id " hwnd)
}
