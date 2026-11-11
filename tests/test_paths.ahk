#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ../src/lib/shell.ahk
#Include ../src/utils/tooltip.ahk
#Include ../src/rules/paths.ahk
#Include ../src/ui/popup_menu.ahk
#Include ../src/actions/paths.ahk

class PathMenuTests {
    static Count := 0
    static MenuDelay := 300
    static TipDelay := 100
    class RecordingTooltip {
        Show(text, duration) => this.Text := text
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static Open(target, folder) {
        this.Target := target
        this.Folder := folder
    }
    static FailOpen(*) {
        throw Error("test failure")
    }
    static Dismiss(owner, pid, result) {
        visible := WinWait("ahk_class #32768 ahk_pid " pid,, 3)
        FileAppend(visible ? "visible" : "missing", result, "UTF-8")
        DllCall("PostMessageW", "Ptr", Integer(owner), "UInt", 0x001F, "UPtr", 0, "Ptr", 0)
    }
    static Run() {
        items := PathMenuBindings.Create(A_ScriptDir "\..")
        tip := this.RecordingTooltip()
        actions := PathMenuActions(tip, ObjBindMethod(this, "Open"))
        view := PopupMenuView(items, ObjBindMethod(actions, "Open"))
        this.Assert(DllCall("GetMenuItemCount", "Ptr", view.Menu.Handle) == 13, "Native root menu contains legacy entries")
        this.Assert(DllCall("GetMenuState", "Ptr", view.Menu.Handle, "UInt", 0, "UInt", 0x400) & 3, "Menu title is disabled")
        for index in [9, 10, 11] {
            child := DllCall("GetSubMenu", "Ptr", view.Menu.Handle, "Int", index - 1, "Ptr")
            this.Assert(child && DllCall("GetMenuItemCount", "Ptr", child) == items[index].Items.Length, "Native submenu populated")
        }
        this.Assert(DirExist(ShellTools.KnownFolder(PathMenuBindings.KnownFolders["Downloads"])), "Known-folder API resolves actual Downloads directory")
        for group in [items, items[9].Items, items[10].Items, items[11].Items] {
            for item in group {
                if !IsObject(item) || item.HasOwnProp("Items") || item.Target == ""
                    continue
                actions.Open(item)
                this.Assert(this.Target == item.Target && this.Folder == item.Folder, "Menu action retains target and launch type: " item.Name)
                this.Assert(tip.Text == "打开 " item.Name, "Successful launch feedback: " item.Name)
            }
        }
        actions.Open(PathMenuBindings.Folder("带空格目录", "C:\path with spaces"))
        this.Assert(this.Target == "C:\path with spaces", "Folder target retains spaces")
        actions.Open(items[-1])
        this.Assert(this.Target == "C:\path with spaces", "Exit item launches nothing")
        failing := PathMenuActions(tip, ObjBindMethod(this, "FailOpen"))
        failing.Open(items[3])
        this.Assert(InStr(tip.Text, "无法打开 资源管理器"), "Launch failure produces feedback")
        if !A_Args.Length || A_Args[1] != "--pure" {
            result := A_ScriptDir "\..\tmp\path-menu-" A_TickCount ".txt"
            Run('"' A_AhkPath '" /ErrorStdOut "' A_ScriptFullPath '" --dismiss ' A_ScriptHwnd ' ' DllCall("GetCurrentProcessId") ' "' result '"',, "Hide")
            view.Show()
            this.Assert(FileRead(result, "UTF-8") == "visible", "Native popup is visible and dismisses on cancellation")
            presenter := TooltipPresenter()
            presenter.Show("提示自动消失测试", this.TipDelay)
            this.Assert(WinExist("ahk_class tooltips_class32 ahk_pid " DllCall("GetCurrentProcessId")), "Native tooltip is visible")
            Sleep(this.MenuDelay)
            this.Assert(!WinExist("ahk_class tooltips_class32 ahk_pid " DllCall("GetCurrentProcessId")), "Native tooltip hides on its one-shot timer")
        }
        FileAppend("PASS: " this.Count " path menu and feedback assertions`n", "*", "UTF-8")
    }
}
try {
    if A_Args.Length && A_Args[1] == "--dismiss"
        PathMenuTests.Dismiss(A_Args[2], A_Args[3], A_Args[4])
    else
        PathMenuTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack, "**", "UTF-8")
    ExitApp(1)
}
