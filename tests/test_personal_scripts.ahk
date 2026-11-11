#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/utils/filesystem.ahk
#Include ../src/rules/ime.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/editing.ahk
#Include ../src/core/settings.ahk
#Include ../src/actions/personal_scripts.ahk
#Include ../src/actions/unicode_inspector.ahk

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
    static Missing(action, message) {
        failed := false
        try action.Call()
        catch Error
            failed := true
        this.Assert(failed, message)
    }
    static Run() {
        directory := A_ScriptDir "\..\tmp\personal scripts test " DllCall("GetCurrentProcessId")
        scriptDirectory := directory "\tools\others"
        DirCreate(scriptDirectory)
        script := directory "\" UnicodeInspectorActions.Script
        psLauncher := directory "\run-script.ps1", pyLauncher := directory "\run-script.py"
        savedPath := EnvGet("PATH")
        manager := Config.Manager("settings.json", directory)
        settings := manager.Register(AppSettings.PersonalScripts(), "PersonalScripts")
        manager.LoadAll()
        python := this.Python(), clipboard := this.Clipboard()
        actions := PersonalScripts(python, settings, ObjBindMethod(manager, "SaveAll"))
        inspector := UnicodeInspectorActions(actions, clipboard)
        resolve := ObjBindMethod(actions, "ResolveScript", UnicodeInspectorActions.Script)
        try {
            FileAppend("", psLauncher), FileAppend("", pyLauncher), FileAppend("", script)
            EnvSet("PATH", '"' directory '"')
            target := resolve.Call()
            this.Assert(target.Script == script && target.Directory == directory, "Direct target relative to launcher")
            this.Assert(settings.launcherPath == psLauncher, "Find PowerShell launcher on PATH")
            this.Assert(Config.LoadJson(manager.Path)["PersonalScripts"]["launcherPath"] == psLauncher, "Persist discovered launcher")
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
            clipboard.Success := false
            inspector.Open({Hwnd: 0})
            this.Assert(!python.Last.Arguments.Length, "No selection opens empty inspector")
            FileDelete(script)
            this.Missing(resolve, "Missing target reports error")
            FileDelete(pyLauncher)
            this.Missing(resolve, "Missing cached launcher and PATH entry reports error")
            FileAppend("PASS: " this.Count " personal-script assertions`n", "*", "UTF-8")
        } finally {
            EnvSet("PATH", savedPath)
            for path in [script, psLauncher, pyLauncher, manager.Path] {
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
