#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ../src/lib/keyboard.ahk
class ModifierRestoreTests {
    static SystemCommand := 0x0112
    static KeyMenu := 0xF100
    static Query := 0x8001
    static CloseMessage := 0x0010
    static MenuCount := 0
    static PhysicalMarker := 0xFFC3D44E
    static KeyUp := 2
    static SelectText := 0x00B1
    static Delay := 80
    static OnSystemCommand(command, *) {
        if (command & 0xFFF0) == this.KeyMenu {
            this.MenuCount++
            return 0
        }
    }
    static OnQuery(*) => this.MenuCount
    static Noop(*) => 0
    static Receiver() {
        this.Window := Gui(, A_Args[2])
        fileMenu := Menu()
        fileMenu.Add("Test", ObjBindMethod(this, "Noop"))
        bar := MenuBar()
        bar.Add("&File", fileMenu)
        this.Window.MenuBar := bar
        this.Window.AddEdit("w400 h100 Multi WantTab", "Selected text")
        this.Window.OnEvent("Close", (*) => ExitApp())
        OnMessage(this.SystemCommand, ObjBindMethod(this, "OnSystemCommand"))
        OnMessage(this.Query, ObjBindMethod(this, "OnQuery"))
        this.Window.Show()
    }
    static Physical(key, down) {
        DllCall("keybd_event", "UChar", GetKeyVK(key), "UChar", GetKeySC(key), "UInt", down ? 0 : this.KeyUp, "UPtr", this.PhysicalMarker)
        Sleep(this.Delay)
    }
    static Count(hwnd) => SendMessage(this.Query, 0, 0,, "ahk_id " hwnd)
    static Press(key) {
        SendEvent("{Blind}{" key " down}{" key " up}")
        Sleep(200)
    }
    static MainFeedback(hwnd) {
        DetectHiddenWindows(true)
        SplitPath(A_ScriptDir,, &root)
        owner := WinExist(root "\main.ahk ahk_class AutoHotkey")
        if !owner
            throw Error("Main script is not running")
        pid := WinGetPID("ahk_id " owner)
        DetectHiddenWindows(false)
        edit := ControlGetHwnd("Edit1", "ahk_id " hwnd)
        SendLevel(1)
        for shift in [false, true] {
            ControlFocus(edit)
            ControlSetText("sample", edit)
            SendMessage(this.SelectText, 0, -1, edit)
            before := this.Count(hwnd)
            try {
                SendEvent("{Blind}{F24 down}")
                this.Physical("F24", true)
                this.Physical("LAlt", true)
                if shift
                    this.Physical("LShift", true)
                this.Press("c")
                this.Press("Enter")
                expected := shift ? "输入回车换行符（CRLF）" : "输入换行符（LF）"
                tip := WinExist("ahk_class tooltips_class32 ahk_pid " pid)
                actual := tip ? ControlGetText(tip) : ""
                if actual != expected
                    throw Error("Special newline tooltip mismatch: expected=" expected ", actual=" actual ", tip=" tip ", pid=" pid ", length=" StrLen(ControlGetText(edit)))
            } finally {
                if shift
                    this.Physical("LShift", false)
                this.Physical("LAlt", false)
                this.Physical("F24", false)
                SendEvent("{Blind}{F24 up}")
                Sleep(this.Delay)
            }
            if this.Count(hwnd) != before
                throw Error("Layer hotkeys activated native menu")
            FileAppend("PASS: layer " (shift ? 4 : 3) " newline tooltip and no menu activation after C/Enter`n", "*")
        }
    }
    static Run() {
        InstallKeybdHook()
        title := "Modifier restore verification " DllCall("GetCurrentProcessId")
        Run('"' A_AhkPath '" /ErrorStdOut "' A_ScriptFullPath '" --receiver "' title '"',, "Hide", &pid)
        hwnd := WinWait(title " ahk_pid " pid,, 3)
        if !hwnd
            throw Error("Receiver did not open")
        saved := ClipboardAll()
        sender := KeyboardSender()
        try {
            WinActivate("ahk_id " hwnd)
            if !WinWaitActive("ahk_id " hwnd,, 2)
                throw Error("Receiver could not take focus")
            ControlFocus("Edit1", "ahk_id " hwnd)
            if A_Args.Length && A_Args[1] == "--main" {
                this.MainFeedback(hwnd)
                return
            }
            ; 校准：无其他按键的 Alt 应被接收窗口识别为菜单操作。
            before := this.Count(hwnd)
            this.Physical("LAlt", true)
            this.Physical("LAlt", false)
            if this.Count(hwnd) <= before
                throw Error("Receiver cannot detect standalone Alt")
            failures := 0
            for alt in ["LAlt", "RAlt"] {
                for shift in [false, true] {
                    before := this.Count(hwnd)
                    modifiers := Map(alt, true)
                    this.Physical(alt, true)
                    if shift {
                        this.Physical("LShift", true)
                        modifiers["LShift"] := true
                    }
                    if !GetKeyState(alt, "P")
                        throw Error("Physical modifier state was not established")
                    ; 与分层动作相同：释放、发送复制、恢复仍按住的修饰键。
                    loop 2 {
                        sender.ReleaseModifiers()
                        sender.Send("^c")
                        sender.RestoreModifiers(modifiers)
                        Sleep(this.Delay)
                        if !GetKeyState(alt)
                            throw Error("Held Alt was not restored")
                    }
                    if shift
                        this.Physical("LShift", false)
                    this.Physical(alt, false)
                    menus := this.Count(hwnd) - before
                    FileAppend(alt " shift=" shift " menu activations=" menus "`n", "*")
                    failures += menus
                }
            }
            if failures
                throw Error("Restored modifiers activated menu " failures " times")
            FileAppend("PASS: native modifier restoration keeps held Alt without activating menus`n", "*")
        } finally {
            sender.Send("{vkE8}{LShift up}{LAlt up}{RAlt up}")
            A_Clipboard := saved
            PostMessage(this.CloseMessage, 0, 0,, "ahk_id " hwnd)
            ProcessWaitClose(pid, 2)
        }
    }
}
try {
    if A_Args.Length && A_Args[1] == "--receiver"
        ModifierRestoreTests.Receiver()
    else {
        ModifierRestoreTests.Run()
        ExitApp(0)
    }
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
