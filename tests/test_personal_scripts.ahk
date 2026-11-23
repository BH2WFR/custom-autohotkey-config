#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/lib/python.ahk
#Include ../src/utils/filesystem.ahk
#Include ../src/rules/ime.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/editing.ahk
#Include ../src/core/settings.ahk
#Include ../src/actions/personal_scripts.ahk
#Include ../src/actions/unicode_inspector.ahk
#Include ../src/actions/application.ahk

class PersonalScriptsTests {
    static Count := 0
    class Python {
        Launch(script, arguments, directory, windowed := true) {
            this.Last := {Script: script, Arguments: arguments, Directory: directory}
            return 123
        }
    }
    class Clipboard {
        Success := true
        Text := '--clip 中文 "quoted"`nsecond line\'
        Read(keys) => {Success: this.Success, Text: this.Text}
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static DismissWarning() {
        if hwnd := WinExist("PersonalScripts ahk_class #32770 ahk_pid " ProcessExist()) {
            this.WarningText := WinGetText(hwnd)
            ControlClick("Button2", hwnd)
        }
    }
    static Missing(action, reason) {
        this.WarningText := ""
        dismiss := ObjBindMethod(this, "DismissWarning")
        SetTimer(dismiss, 30)
        try result := action.Call()
        finally SetTimer(dismiss, 0)
        this.Assert(!result && InStr(this.WarningText, reason)
            && InStr(this.WarningText, "https://github.com/BH2WFR/PersonalScripts"), "Installation warning: " reason)
    }
    static Run() {
        directory := A_ScriptDir "\..\tmp\personal scripts test " DllCall("GetCurrentProcessId")
        scriptDirectory := directory "\tools\others"
        DirCreate(scriptDirectory)
        script := directory "\" UnicodeInspectorActions.Script
        psLauncher := directory "\run-script.ps1", pyLauncher := directory "\run-script.py"
        savedPath := EnvGet("PATH")
        localAppData := EnvGet("LOCALAPPDATA"), parentSession := EnvGet("WT_SESSION")
        manager := Config.Manager("settings.json", directory)
        settings := manager.Register(AppSettings.PersonalScripts(), "PersonalScripts")
        manager.LoadAll()
        python := this.Python(), clipboard := this.Clipboard()
        actions := PersonalScripts(python, settings, ObjBindMethod(manager, "SaveAll"),
            ObjBindMethod(ApplicationActions, "OfferPersonalScriptsInstall"))
        inspector := UnicodeInspectorActions(actions, clipboard)
        resolve := ObjBindMethod(actions, "ResolveScript", UnicodeInspectorActions.Script)
        try {
            FileAppend("", psLauncher), FileAppend("", pyLauncher), FileAppend("", script)
            EnvSet("PATH", '"' directory '"')
            target := resolve.Call()
            this.Assert(target.Script == script && target.Directory == directory, "Direct target relative to launcher")
            this.Assert(settings.launcherPath == psLauncher, "Find PowerShell launcher on PATH")
            this.Assert(Config.LoadJson(manager.Path)["PersonalScripts"]["launcherPath"] == psLauncher, "Persist discovered launcher")
            runtime := PythonRuntime("base")
            consoleTools := PersonalScripts(runtime, settings, ObjBindMethod(manager, "SaveAll"),
                ObjBindMethod(ApplicationActions, "OfferPersonalScriptsInstall"))
            probe := "import ctypes, msvcrt, os, sys`nfrom pathlib import Path`n"
                . "valid = sys.stdin.isatty() and len(sys.argv) == 1`n"
                . "for stream in (sys.stdout, sys.stderr):`n"
                . "    handle = ctypes.c_void_p(msvcrt.get_osfhandle(stream.fileno()))`n"
                . "    mode = ctypes.c_ulong()`n"
                . "    assert ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode))`n"
                . "    valid = valid and (mode.value & 5) == 5`n"
                . "Path('console.tmp').write_text(str(valid) + ':' + os.getenv('WT_SESSION', ''), encoding='utf-8')`n"
                . "Path('console.tmp').replace('console.txt')"
            FileAppend(probe, pyLauncher, "UTF-8-RAW")
            EnvSet("WT_SESSION", "")
            for useTerminal in [true, false] {
                EnvSet("PATH", useTerminal ? savedPath : directory)
                EnvSet("LOCALAPPDATA", useTerminal ? localAppData : directory)
                if useTerminal && !PythonRuntime.FindWindowsTerminal()
                    continue
                pid := consoleTools.LaunchConsole("run-script.py")
                deadline := A_TickCount + 10000
                result := directory "\console.txt"
                while !FileExist(result) && A_TickCount < deadline
                    Sleep(25)
                this.Assert(pid && FileExist(result), "Console tool ran in its library directory")
                output := FileRead(result, "UTF-8")
                this.Assert(InStr(output, "True:") == 1 && (!useTerminal || StrLen(output) > 5),
                    "Requested terminal runs the probe with interactive input and ANSI output: " output)
                FileDelete(result)
            }
            EnvSet("LOCALAPPDATA", localAppData)
            EnvSet("PATH", "")
            this.Assert(resolve.Call().Script == script, "Saved path works without PATH discovery")
            EnvSet("PATH", directory)
            FileDelete(psLauncher)
            this.Assert(resolve.Call().Script == script && settings.launcherPath == pyLauncher, "Stale setting falls back to Python launcher")
            this.Assert(Config.LoadJson(manager.Path)["PersonalScripts"]["launcherPath"] == pyLauncher, "Replacement path persisted")
            this.Assert(inspector.Open({Hwnd: 0}) == 123, "Launch returns process ID")
            this.Assert(python.Last.Script == script && python.Last.Directory == directory, "Launch target directly, not launcher")
            this.Assert(python.Last.Arguments.Length == 2 && python.Last.Arguments[1] == "--"
                && python.Last.Arguments[2] == clipboard.Text, "Pass selected text literally, including leading options and Unicode")
            inspector.Open()
            this.Assert(python.Last.Arguments.Length == 1 && python.Last.Arguments[1] == "--clip",
                "Tray launch asks the viewer to read clipboard text even when text is selected")
            clipboard.Success := false
            inspector.Open({Hwnd: 0})
            this.Assert(!python.Last.Arguments.Length, "No selection opens empty inspector")
            FileDelete(script)
            this.Missing(ObjBindMethod(actions, "Launch", UnicodeInspectorActions.Script), UnicodeInspectorActions.Script)
            FileDelete(pyLauncher)
            this.Missing(ObjBindMethod(inspector, "Open", {Hwnd: 0}), "找不到 PersonalScripts 入口")
            FileAppend("PASS: " this.Count " personal-script assertions`n", "*", "UTF-8")
        } finally {
            EnvSet("PATH", savedPath)
            EnvSet("LOCALAPPDATA", localAppData)
            EnvSet("WT_SESSION", parentSession)
            for path in [script, psLauncher, pyLauncher, manager.Path, directory "\console.txt"] {
                if FileExist(path)
                    FileDelete(path)
            }
            DirDelete(scriptDirectory)
            DirDelete(directory "\tools")
            DirDelete(directory)
        }
    }
}
try {
    PersonalScriptsTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
