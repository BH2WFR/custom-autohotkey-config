#Requires AutoHotkey v2.0
#Include ../src/rules/windows.ahk

class WindowGroupTests {
    static Count := 0

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }

    static Run() {
        this.Assert(WindowGroups.IsAnkiProcess("ANKI.EXE", "C:\Apps\anki.exe"), "Anki executable is case insensitive")
        this.Assert(WindowGroups.IsAnkiProcess("pythonw.exe", "C:\Apps\AnkiProgramFiles\env\pythonw.exe"), "Anki Python entry")
        this.Assert(WindowGroups.IsAnkiProcess("PYTHONW.EXE", "C:\Apps\ankiprogramfiles\pythonw.exe"), "Anki path is case insensitive")
        this.Assert(!WindowGroups.IsAnkiProcess("pythonw.exe", "C:\Python\pythonw.exe"), "Unrelated Python GUI is excluded")
        this.Assert(!WindowGroups.IsAnkiProcess("pythonw.exe", "C:\Apps\NotAnkiProgramFiles\pythonw.exe"), "Directory name must match")
        this.Assert(!WindowGroups.IsAnkiProcess("pythonw.exe", "C:\Apps\AnkiProgramFiles-old\pythonw.exe"), "Directory suffix is excluded")
        this.Assert(!WindowGroups.IsAnkiProcess("notanki.exe", "C:\Apps\AnkiProgramFiles\notanki.exe"), "Process name must match")

        WindowGroups.Register()
        window := Gui(, "Add")
        window.Show("NA w240 h80")
        hwnd := window.Hwnd
        try {
            this.Assert(!WindowGroups.Matches(WindowGroups.AnkiEditor, hwnd), "An Add window outside Anki is excluded")
            GroupAdd(WindowGroups.Anki, "ahk_id " hwnd)
            for title in ["Add", "Edit Current", "Browse - Deck", "添加", "编辑当前", "浏览 - 牌组"] {
                window.Title := title
                this.Assert(WindowGroups.Matches(WindowGroups.AnkiEditor, hwnd), "Anki editing window: " title)
            }
            window.Title := "Preferences"
            this.Assert(WindowGroups.Matches(WindowGroups.Anki, hwnd), "Other Anki windows retain app classification")
            this.Assert(!WindowGroups.Matches(WindowGroups.AnkiEditor, hwnd), "Anki preferences are not an editor")

            this.Assert(!WindowGroups.Matches(WindowGroups.MiddleDragLeft, hwnd), "Ordinary window does not support image drag")
            GroupAdd(WindowGroups.ImageViewer, "ahk_id " hwnd)
            this.Assert(WindowGroups.Matches(WindowGroups.MiddleDragLeft, hwnd), "Image viewers inherit left-button drag")
            this.Assert(!WindowGroups.Matches(WindowGroups.MiddleDragSpaceLeft, hwnd), "Image drag does not imply Adobe drag")

            GroupAdd(WindowGroups.VirtualMachine, "ahk_id " hwnd)
            this.Assert(WindowGroups.Matches(WindowGroups.XButtonPassthrough, hwnd), "VM inherits side-button passthrough")
            this.Assert(!WindowGroups.Matches(WindowGroups.RemoteDesktop, hwnd), "VM does not inherit remote Caps policy")
        } finally window.Destroy()
        this.Assert(!WindowGroups.Matches(WindowGroups.AnkiEditor, hwnd), "Closed window no longer matches")
        this.Assert(!WindowGroups.Matches(WindowGroups.Anki, 0), "Missing foreground window does not match")

        window := Gui(, "Composite group test")
        window.Show("NA w240 h80")
        try {
            GroupAdd(WindowGroups.ChatImageViewer, "ahk_id " window.Hwnd)
            this.Assert(WindowGroups.Matches(WindowGroups.MiddleDragLeft, window.Hwnd), "Chat images inherit left-button drag")
            this.Assert(!WindowGroups.Matches(WindowGroups.ImageViewer, window.Hwnd), "Chat images do not inherit picture navigation")
            GroupAdd(WindowGroups.RemoteDesktop, "ahk_id " window.Hwnd)
            this.Assert(WindowGroups.Matches(WindowGroups.XButtonPassthrough, window.Hwnd), "Remote desktop inherits side-button passthrough")
        } finally window.Destroy()
        FileAppend("PASS: " this.Count " window classification assertions" Chr(10), "*", "UTF-8")
    }
}

try {
    WindowGroupTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}
