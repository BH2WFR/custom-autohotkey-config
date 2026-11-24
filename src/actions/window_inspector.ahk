; 把触发时的窗口身份交给 PersonalScripts；托盘用零句柄打开空白查看器。
class WindowInspectorActions {
    static Script := "tools\others\window-inspector.py"
    static StartupTimeoutSeconds := 10

    __New(scripts) {
        this.Scripts := scripts
    }

    Open(context := unset) {
        hwnd := IsSet(context) ? context.Hwnd : 0
        pid := hwnd ? WinGetPID(hwnd) : 0
        inspectorPid := this.Scripts.Launch(WindowInspectorActions.Script, ["--startup-window", hwnd, pid])
        if inspectorPid {
            inspector := WinWait("Window Inspector ahk_pid " inspectorPid,, WindowInspectorActions.StartupTimeoutSeconds)
            if !inspector
                throw TargetError("未找到新启动的窗口信息查看器。")
            WinActivate(inspector)
        }
        return inspectorPid
    }
}
