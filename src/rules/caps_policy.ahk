; 项目别名和远程桌面策略；钩子只使用注入的路由结果。
class CapsPolicy {
    __New(settings, matches := unset) {
        this.Settings := settings
        this.Matches := IsSet(matches) ? matches : ObjBindMethod(WindowGroups, "Matches")
    }

    static ConfigurableAliases := Map("CapsLock", "capsLockAlias", "F1", "f1Alias", "F24", "f24Alias")

    static Aliases(settings) {
        aliases := Map()
        for key, property in this.ConfigurableAliases
            aliases[key] := !!settings.%property%
        return aliases
    }

    Resolve(key, hwnd) {
        remote := this.Matches.Call(WindowGroups.RemoteDesktop, hwnd)
            || this.Matches.Call(WindowGroups.VirtualMachine, hwnd)
        return remote ? this.Settings.capsMode : "layer"
    }
}
