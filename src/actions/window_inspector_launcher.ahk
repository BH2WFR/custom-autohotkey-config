; 独立 GUI 线程处理原生下拉框消息，主进程继续响应全局键鼠钩子。
class WindowInspectorLauncher {
    static EndpointTitle := "WindowInspectorEndpoint"
    static OpenMessage := 0x8003
    static ReadyTimeout := 3
    static StartupTipMs := 800
    Pid := 0
    Starting := false

    __New(root, tooltip) {
        this.Script := root "\src\ui\window_inspector_main.ahk"
        this.Tooltip := tooltip
    }

    Endpoint() => this.Pid ? WinExist(WindowInspectorLauncher.EndpointTitle " ahk_class AutoHotkeyGUI ahk_pid " this.Pid) : 0

    Open(context) {
        this.Target := context.Hwnd
        if this.Starting
            return
        previous := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try {
            if !(endpoint := this.Endpoint()) {
                this.Starting := true
                this.Tooltip.Show("窗口信息查看器：正在启动，请稍等…", WindowInspectorLauncher.StartupTipMs)
                Run('"' A_AhkPath '" /ErrorStdOut "' this.Script '" ' A_ScriptHwnd,,, &pid)
                this.Pid := pid
                endpoint := WinWait(WindowInspectorLauncher.EndpointTitle " ahk_class AutoHotkeyGUI ahk_pid " pid,, WindowInspectorLauncher.ReadyTimeout)
                if !endpoint
                    throw Error("窗口信息查看器未能启动。")
            }
            DllCall("AllowSetForegroundWindow", "UInt", this.Pid)
            PostMessage(WindowInspectorLauncher.OpenMessage, this.Target, A_ScriptHwnd,, endpoint)
        } finally {
            this.Starting := false
            DetectHiddenWindows(previous)
        }
    }

    Close() {
        previous := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try {
            if endpoint := this.Endpoint()
                WinClose(endpoint)
        } finally {
            this.Pid := 0
            DetectHiddenWindows(previous)
        }
    }
}
