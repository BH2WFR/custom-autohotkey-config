; 私人脚本库的定位与调用；解释器及进程启动复用 PythonRuntime。
class PersonalScripts {
    static Launchers := ["run-script.ps1", "run-script.py"]
    static ProjectUrl := "https://github.com/BH2WFR/PersonalScripts"
    static StartupTimeoutSeconds := 10

    __New(python, settings, save, warnMissing, onLaunching) {
        this.Python := python
        this.Settings := settings
        this.Save := save
        this.WarnMissing := warnMissing
        this.OnLaunching := onLaunching
    }

    ResolveScript(relativePath) {
        launcher := this.Settings.launcherPath
        attributes := FileExist(launcher)
        if !attributes || InStr(attributes, "D") {
            launcher := ""
            for name in PersonalScripts.Launchers {
                if launcher := FileSystem.FindOnPath(name)
                    break
            }
            if launcher == ""
                throw TargetError("找不到 PersonalScripts 入口（run-script.ps1 或 run-script.py）。")
            this.Settings.launcherPath := launcher
            this.Save.Call()
        }
        SplitPath(launcher,, &root)
        script := root "\" relativePath
        attributes := FileExist(script)
        if !attributes || InStr(attributes, "D")
            throw TargetError("找不到 PersonalScripts 工具入口：" relativePath)
        return {Script: script, Directory: root}
    }

    LaunchConsole(relativePath) => this.Launch(relativePath, [], PythonRuntime.ConsoleMode)

    LaunchWindow(relativePath, title, arguments := []) {
        pid := this.Launch(relativePath, arguments)
        if pid {
            hwnd := WinWait(title " ahk_pid " pid,, PersonalScripts.StartupTimeoutSeconds)
            if !hwnd
                throw TargetError("未找到新启动的窗口：" title)
            WinActivate(hwnd)
        }
        return pid
    }

    Launch(relativePath, arguments := [], mode := PythonRuntime.GuiMode) {
        try target := this.ResolveScript(relativePath)
        catch TargetError as err {
            this.WarnMissing.Call(err.Message, PersonalScripts.ProjectUrl)
            return 0
        }
        SplitPath(relativePath,,,, &name)
        this.OnLaunching.Call(name)
        return this.Python.Launch(target.Script, arguments, target.Directory, mode)
    }
}
