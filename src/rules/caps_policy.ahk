; 项目别名和远程桌面策略；钩子只使用注入的路由结果。
class CapsPolicy {
    static DebugMode := true

    __New(settings, matches := unset) {
        this.Settings := settings
        this.Matches := IsSet(matches) ? matches : ObjBindMethod(WindowGroups, "Matches")
    }

    static Aliases(f1) => Map(
        "CapsLock", true,
        "F1", !!f1,
        "F24", true,
        "F6", this.DebugMode)

    Resolve(key, hwnd) {
        return this.Matches.Call(WindowGroups.RemoteDesktop, hwnd) ? this.Settings.capsMode : "layer"
    }
}
