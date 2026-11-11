; 私人脚本库的定位与调用；解释器及进程启动复用 PythonRuntime。
class PersonalScripts {
    static Launchers := ["run-script.ps1", "run-script.py"]

    __New(python, settings, save) {
        this.Python := python
        this.Settings := settings
        this.Save := save
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
                throw Error("找不到 PersonalScripts 启动器，请在设置中指定 launcherPath，或将 run-script.ps1 / run-script.py 所在目录加入 PATH。")
            this.Settings.launcherPath := launcher
            this.Save.Call()
        }
        SplitPath(launcher,, &root)
        script := root "\" relativePath
        if !FileExist(script)
            throw Error("找不到脚本：" script)
        return {Script: script, Directory: root}
    }

    Launch(relativePath, arguments := [], windowed := true) {
        target := this.ResolveScript(relativePath)
        return this.Python.Launch(target.Script, arguments, target.Directory, windowed)
    }
}
