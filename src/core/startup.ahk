; 启动权限入口，沿用 AHK-SysUtil 的 RunAs + /restart 流程。
class Startup {
    static RestartSwitch := "/restart"
    static RestartPattern := "i) /restart(?!\S)"

    static IsAdmin() => !!A_IsAdmin

    static RequireAdmin() {
        if this.IsAdmin()
            return
        ; 重启后仍未取得权限时退出，不再次请求提权。
        commandLine := DllCall("GetCommandLineW", "Str")
        if RegExMatch(commandLine, this.RestartPattern) {
            OutputDebug("启动失败：未取得管理员权限。")
            ExitApp(1)
        }
        command := A_IsCompiled
            ? '*RunAs "' A_ScriptFullPath '" ' this.RestartSwitch
            : '*RunAs "' A_AhkPath '" ' this.RestartSwitch ' "' A_ScriptFullPath '"'
        try Run(command, A_ScriptDir)
        catch OSError as err {
            OutputDebug("管理员启动未完成：" err.Message)
            ExitApp(1)
        }
        ExitApp()
    }
}
