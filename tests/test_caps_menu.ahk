#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ../src/lib/ime.ahk
; 对正在运行的 main.ahk 发送真实钩子事件，检查菜单连续打开及收尾。
class CapsMenuTests {
    static EscapeCount := 0
    static ECount := 0
    static KeyDownMessage := 0x0100
    static EscapeKey := 0x1B
    static EKey := 0x45
    static CancelModeMessage := 0x001F
    static QueryKeyMessage := 0x8001
    static CloseMessage := 0x0010
    ; AutoHotkey v2 source/keyboard_mouse.h: 更新其他钩子的物理状态，不触发热键。
    static PhysicalMarker := 0xFFC3D44E
    static KeyUpFlag := 2
    static SettleDelay := 100
    static PointSize := 8
    static KeyDown(key, *) {
        if key == this.EscapeKey
            this.EscapeCount++
        if key == this.EKey
            this.ECount++
    }
    static QueryKey(key, *) => key == this.EscapeKey ? this.EscapeCount : this.ECount

    static Receiver() {
        window := Gui(, A_Args[2])
        window.AddEdit("w400 h100")
        window.OnEvent("Close", (*) => ExitApp())
        OnMessage(this.KeyDownMessage, ObjBindMethod(this, "KeyDown"))
        OnMessage(this.QueryKeyMessage, ObjBindMethod(this, "QueryKey"))
        window.Show()
        this.ReceiverWindow := window
    }

    class RemoteEdit {
        __New(hwnd) => this.Hwnd := hwnd
        Value {
            get => ControlGetText(this.Hwnd)
            set => ControlSetText(value, this.Hwnd)
        }
        Focus() => ControlFocus(this.Hwnd)
    }

    static Position() {
        point := Buffer(this.PointSize)
        DllCall("GetPhysicalCursorPos", "Ptr", point)
        return {X: NumGet(point, 0, "Int"), Y: NumGet(point, 4, "Int")}
    }
    static Press(key) {
        SendEvent("{Blind}{" key " down}{" key " up}")
        Sleep(this.SettleDelay)
    }
    static PhysicalState(key, down) {
        DllCall("keybd_event", "UChar", GetKeyVK(key), "UChar", GetKeySC(key),
            "UInt", down ? 0 : this.KeyUpFlag, "UPtr", this.PhysicalMarker)
        Sleep(30)
    }

    static RepeatedEditing(edit) {
        saved := ClipboardAll()
        edit.Value := ""
        edit.Focus()
        Sleep(this.SettleDelay)
        try {
            A_Clipboard := "Ab1"
            SendEvent("{Blind}{F24 down}")
            for key in ["v", "v", "z", "z", "Space", "Space"] {
                this.Press(key)
            }
            this.PhysicalState("LShift", true)
            this.Press("Space")
            this.Press("Space")
            this.PhysicalState("LShift", false)
            expected := "Ab1Ab1Ab1Ab1" Chr(0xA0) Chr(0xA0) Chr(0x3000) Chr(0x3000)
            if edit.Value != expected
                throw Error("Repeated paste/typing/spaces failed: " edit.Value)
            FileAppend("PASS: repeated paste, typing and both special spaces in one Layer session`n", "*")
        } finally {
            this.PhysicalState("LShift", false)
            SendEvent("{Blind}{F24 up}")
            A_Clipboard := saved
        }
    }

    static OnceAbsorbs(owner, pid, edit) {
        edit.Value := ""
        receiver := DllCall("GetParent", "Ptr", edit.Hwnd, "Ptr")
        previous := SendMessage(this.QueryKeyMessage, this.EKey, 0,, "ahk_id " receiver)
        try {
            SendEvent("{Blind}{F24 down}")
            this.PhysicalState("F24", true)
            SendEvent("{Blind}{e down}")
            Sleep(150)
            SendEvent("{Blind}{e up}")
            Sleep(150)
            if !WinExist("ahk_class #32768 ahk_pid " pid)
                throw Error("One-shot menu did not open")
            DllCall("PostMessageW", "Ptr", owner, "UInt", this.CancelModeMessage, "UPtr", 0, "Ptr", 0)
            Sleep(250)
            this.Press("e")
            this.Press("e")
            if WinExist("ahk_class #32768 ahk_pid " pid) || edit.Value != ""
                || SendMessage(this.QueryKeyMessage, this.EKey, 0,, "ahk_id " receiver) != previous
                throw Error("One-shot key leaked or reopened menu with Layer held")
            FileAppend("PASS: repeated E is absorbed after menu close until Layer release`n", "*")
        } finally {
            this.PhysicalState("F24", false)
            SendEvent("{Blind}{e up}{F24 up}")
            DllCall("PostMessageW", "Ptr", owner, "UInt", this.CancelModeMessage, "UPtr", 0, "Ptr", 0)
        }
    }
    static HeldSession(window) {
        WinActivate("ahk_id " window.Hwnd)
        if !WinWaitActive("ahk_id " window.Hwnd,, 2)
            throw Error("Test window has no focus")
        Sleep(this.SettleDelay)
        saved := this.Position()
        try {
            SendLevel(1)
            SetKeyDelay(30, -1)
            SendEvent("{F24 down}")
            for key in ["q", "l", "q", "l", "i", "j", "k"] {
                SendEvent("{" key " down}{" key " up}")
                Sleep(this.SettleDelay)
                if !WinActive("ahk_id " window.Hwnd)
                    throw Error("Test window lost focus after " key)
            }
            position := this.Position()
            escapes := SendMessage(this.QueryKeyMessage, this.EscapeKey, 0,, "ahk_id " window.Hwnd)
            if escapes != 2 || position.X != saved.X + 1 || position.Y != saved.Y
                throw Error("Held Layer session failed: Esc=" escapes ", dx=" (position.X-saved.X) ", dy=" (position.Y-saved.Y))
            FileAppend("PASS: Esc and pointer keys repeat/interleave with Layer held`n", "*")
        } finally {
            SendEvent("{F24 up}")
            DllCall("SetPhysicalCursorPos", "Int", saved.X, "Int", saved.Y)
        }
    }
    static Run() {
        DetectHiddenWindows(true)
        SplitPath(A_ScriptDir, , &root)
        owner := WinExist(root "\main.ahk ahk_class AutoHotkey")
        if !owner
            throw Error("Main script not running")
        pid := WinGetPID("ahk_id " owner)
        DetectHiddenWindows(false)
        ; 接收输入的 GUI 独立运行，避免测试自身的 SendEvent 阻塞目标消息循环。
        title := "Layer verification " DllCall("GetCurrentProcessId")
        Run('"' A_AhkPath '" /ErrorStdOut "' A_ScriptFullPath '" --receiver "' title '"',, "Hide", &receiverPid)
        hwnd := WinWait(title " ahk_pid " receiverPid,, 3)
        if !hwnd
            throw Error("Test receiver did not open")
        window := {Hwnd: hwnd}
        edit := this.RemoteEdit(ControlGetHwnd("Edit1", "ahk_id " hwnd))
        api := ImeApi()
        imeWindow := api.Window(window.Hwnd)
        opened := imeWindow ? api.Control(imeWindow, ImeApi.GetOpenStatus) : false
        try {
            WinActivate("ahk_id " window.Hwnd)
            if !WinWaitActive("ahk_id " window.Hwnd,, 2)
                throw Error("Test window has no focus")
            SendLevel(1)
            SetKeyDelay(30, -1)
            if A_Args.Length && (A_Args[1] == "--open" || A_Args[1] == "--closed") {
                if imeWindow {
                    api.Control(imeWindow, ImeApi.SetOpenStatus, A_Args[1] != "--closed")
                    Sleep(100)
                }
                FileAppend("IME initial=" opened ", test=" (imeWindow ? api.Control(imeWindow, ImeApi.GetOpenStatus) : -1) "`n", "*")
                this.RepeatedEditing(edit)
                if imeWindow && api.Control(imeWindow, ImeApi.GetOpenStatus) != (A_Args[1] != "--closed")
                    throw Error("Typing did not restore IME state")
                return
            }
            if !A_Args.Length || A_Args[1] != "--input"
                this.HeldSession(window)
            this.RepeatedEditing(edit)
            if imeWindow && api.Control(imeWindow, ImeApi.GetOpenStatus) != opened
                throw Error("Typing did not restore IME state")
            this.OnceAbsorbs(owner, pid, edit)
            loop 4 {
                WinActivate("ahk_id " window.Hwnd)
                if !WinWaitActive("ahk_id " window.Hwnd,, 2)
                    throw Error("Test window has no focus")
                SendLevel(1)
                SetKeyDelay(30, -1)
                SendEvent("{F24 down}{e down}")
                Sleep(150)
                SendEvent("{e up}{F24 up}")
                Sleep(350)
                visible := WinExist("ahk_class #32768 ahk_pid " pid)
                FileAppend("Attempt " A_Index ": visible=" (!!visible) "`n", "*")
                DllCall("PostMessageW", "Ptr", owner, "UInt", this.CancelModeMessage, "UPtr", 0, "Ptr", 0)
                Sleep(250)
                if !visible
                    throw Error("Caps+E failed on attempt " A_Index)
            }
        } finally {
            if imeWindow
                api.Control(imeWindow, ImeApi.SetOpenStatus, opened)
            PostMessage(this.CloseMessage, 0, 0,, "ahk_id " window.Hwnd)
            ProcessWaitClose(receiverPid, 2)
        }
    }
}
try {
    if A_Args.Length && A_Args[1] == "--receiver"
        CapsMenuTests.Receiver()
    else {
        CapsMenuTests.Run()
        ExitApp()
    }
}
catch as err {
    FileAppend(err.Message "`n" err.Stack, "**")
    ExitApp(1)
}
