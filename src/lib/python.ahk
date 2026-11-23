; 从 Conda 的环境记录定位解释器；启动或切换环境时查找，GUI 按需启动。
class PythonRuntime {
    static GuiMode := 1
    static HiddenMode := 0
    static ConsoleMode := 2
    static CreateNewConsole := 0x10
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

    Launch(script, arguments := [], workingDirectory := "", mode := PythonRuntime.GuiMode) {
        if this.Executable == ""
            throw Error("未找到 Conda 环境：" this.Environment)
        executable := mode == PythonRuntime.GuiMode ? StrReplace(this.Executable, "\python.exe", "\pythonw.exe") : this.Executable
        command := PythonRuntime.Quote(executable)
        if mode == PythonRuntime.ConsoleMode {
            SplitPath(A_LineFile,, &libraryDir)
            command .= " " PythonRuntime.Quote(libraryDir "\..\..\py\console_runner.py")
        }
        command .= " " PythonRuntime.Quote(script)
        for argument in arguments
            command .= " " PythonRuntime.Quote(argument)
        if mode == PythonRuntime.ConsoleMode
            return PythonRuntime.RunInConsole(command, workingDirectory)
        Run(command, workingDirectory, mode == PythonRuntime.HiddenMode ? "Hide" : "", &pid)
        return pid
    }

    static RunInConsole(command, directory) {
        terminal := this.FindWindowsTerminal()
        if terminal {
            ; wt 单独解析分号；明确指定新窗口和工作目录，避免受默认配置影响。
            options := "-w new new-tab -d " this.Quote(directory != "" ? directory : A_WorkingDir)
            try {
                Run(this.Quote(terminal) " " StrReplace(options " " command, ";", "\;"), directory,, &pid)
                return pid
            } catch OSError {
                ; 执行别名失效时由系统控制台继续启动。
            }
        }
        ; CreateProcessW 需要可写命令行；新控制台拥有独立的交互输入和输出。
        line := Buffer(StrPut(command, "UTF-16"))
        StrPut(command, line, "UTF-16")
        startup := Buffer(A_PtrSize == 8 ? 104 : 68, 0) ; STARTUPINFOW
        NumPut("UInt", startup.Size, startup)
        process := Buffer(2 * A_PtrSize + 8) ; PROCESS_INFORMATION
        if !DllCall("CreateProcessW", "Ptr", 0, "Ptr", line, "Ptr", 0, "Ptr", 0, "Int", false,
            "UInt", this.CreateNewConsole, "Ptr", 0, "Ptr", directory == "" ? 0 : StrPtr(directory),
            "Ptr", startup, "Ptr", process)
            throw OSError()
        DllCall("CloseHandle", "Ptr", NumGet(process, A_PtrSize, "Ptr"))
        DllCall("CloseHandle", "Ptr", NumGet(process, 0, "Ptr"))
        return NumGet(process, 2 * A_PtrSize, "UInt")
    }

    static FindWindowsTerminal() {
        if terminal := FileSystem.FindOnPath("wt.exe")
            return terminal
        alias := EnvGet("LOCALAPPDATA") "\Microsoft\WindowsApps\wt.exe"
        return FileExist(alias) && !DirExist(alias) ? alias : ""
    }

    static Quote(value) {
        ; Windows argv：引号前及末尾的反斜线需要加倍。
        value := RegExReplace(value, '(\\*)"', '$1$1\"')
        return '"' RegExReplace(value, '(\\+)$', '$1$1') '"'
    }
}
