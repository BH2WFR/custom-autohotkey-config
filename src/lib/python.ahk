; 从 Conda 的环境记录定位解释器；启动或切换环境时查找，GUI 按需启动。
class PythonRuntime {
    __New(environment) {
        this.SetEnvironment(environment)
    }

    SetEnvironment(environment) {
        this.Environment := environment
        this.Executable := PythonRuntime.Resolve(environment)
    }

    static Resolve(name) {
        candidates := []
        if prefix := EnvGet("CONDA_PREFIX")
            candidates.Push(prefix)
        if conda := EnvGet("CONDA_EXE") {
            SplitPath(conda,, &scripts)
            SplitPath(scripts,, &base)
            candidates.Push(base, base "\envs\" name)
        }
        environments := EnvGet("USERPROFILE") "\.conda\environments.txt"
        if FileExist(environments) {
            for line in StrSplit(FileRead(environments, "UTF-8"), "`n", "`r") {
                if Trim(line) != ""
                    candidates.Push(Trim(line))
            }
        }
        for directory in candidates {
            SplitPath(directory, &leaf)
            isBase := FileExist(directory "\Scripts\conda.exe") || FileExist(directory "\condabin\conda.bat")
            if (name == "base" ? isBase : leaf == name) && FileExist(directory "\python.exe")
                return directory "\python.exe"
        }
        return ""
    }

    Launch(script, arguments := [], workingDirectory := "", windowed := true) {
        if this.Executable == ""
            throw Error("未找到 Conda 环境：" this.Environment)
        executable := windowed ? StrReplace(this.Executable, "\python.exe", "\pythonw.exe") : this.Executable
        command := PythonRuntime.Quote(executable) " " PythonRuntime.Quote(script)
        for argument in arguments
            command .= " " PythonRuntime.Quote(argument)
        Run(command, workingDirectory, windowed ? "" : "Hide", &pid)
        return pid
    }

    static Quote(value) {
        ; Windows argv：引号前及末尾的反斜线需要加倍。
        value := RegExReplace(value, '(\\*)"', '$1$1\"')
        return '"' RegExReplace(value, '(\\+)$', '$1$1') '"'
    }
}
