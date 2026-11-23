#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include ../lib/window.ahk
#Include ../lib/window_geometry.ahk
#Include ../lib/window_info.ahk
#Include ../lib/process.ahk
#Include ../lib/shell.ahk
#Include ../utils/tooltip.ahk
#Include ../rules/windows.ahk
#Include ../actions/window.ahk
#Include ../actions/window_inspector.ahk
#Include ../actions/window_inspector_launcher.ahk
#Include dpi_gui.ahk
#Include window_picker.ahk
#Include window_inspector.ahk

class WindowInspectorWorker extends WindowInspectorActions {
    Start(host) {
        this.Host := host
        WindowGroups.Register()
        OnMessage(WindowInspectorLauncher.OpenMessage, ObjBindMethod(this, "Receive"))
        OnMessage(WindowInspectorLauncher.StyleChangedMessage, ObjBindMethod(this, "Receive"))
        OnMessage(WindowInspectorLauncher.PassOpacityMessage, ObjBindMethod(this, "Receive"))
        this.Endpoint := Gui("+ToolWindow")
        this.Endpoint.OnEvent("Close", (*) => this.Close())
        this.Endpoint.Title := WindowInspectorLauncher.EndpointTitle
        if !DllCall("IsWindow", "Ptr", host)
            ExitApp()
        Persistent()
    }

    Receive(value, host, message, hwnd) {
        if host != this.Host || hwnd != this.Endpoint.Hwnd
            return
        switch message {
            case WindowInspectorLauncher.PassOpacityMessage: this.Windows.Settings.passThroughOpacityPercent := value
            case WindowInspectorLauncher.StyleChangedMessage: this.Invoke("RefreshWindowState", value)
            case WindowInspectorLauncher.OpenMessage: this.Open({Hwnd: value})
        }
    }

    Close() {
        super.Close()
        ExitApp()
    }

    static Run() {
        host := Integer(A_Args[1])
        TraySetIcon(A_ScriptDir "\..\..\res\MainIcon.ico")
        tip := TooltipPresenter()
        worker := WindowInspectorWorker(WindowInspectorView, WindowActions(tip, {}), tip, WinGetPID(host))
        worker.Start(host)
    }
}

WindowInspectorWorker.Run()
