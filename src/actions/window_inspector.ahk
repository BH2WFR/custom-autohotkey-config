; 把触发时的窗口身份交给 PersonalScripts；托盘用零句柄打开空白查看器。
class WindowInspectorActions {
    static Script := "tools\others\window-inspector.py"

    __New(scripts) {
        this.Scripts := scripts
    }

    Open(context := unset) {
        hwnd := IsSet(context) ? context.Hwnd : 0
        pid := hwnd ? WinGetPID(hwnd) : 0
        return this.Scripts.LaunchWindow(WindowInspectorActions.Script, "Window Inspector", ["--startup-window", hwnd, pid])
    }
}
