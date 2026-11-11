; 屏幕键盘功能拥有自己的窗口与进程生命周期。
class ScreenKeyboard {
    static CopyDataMessage := 0x004A
    static Protocol := 0x534B01
    static ResetMessage := 0x8001
    static ShowMessage := 0x8002

    __New(python, root) {
        this.Python := python
        this.Root := root
        this.Pid := 0
        this.Queue := []
        this.Receiving := ObjBindMethod(this, "Receive")
        this.Draining := ObjBindMethod(this, "Drain")
        this.Busy := false
        OnMessage(ScreenKeyboard.CopyDataMessage, this.Receiving)
    }

    Connect(input) {
        this.Input := input
    }

    SetEnabled(enabled) {
        this.Input.SetEnabled(enabled)
        this.ResetInput()
    }

    ResetInput() {
        this.Queue := []
        this.Input.ResetInput()
        if this.Pid && hwnd := WinExist("ahk_pid " this.Pid)
            PostMessage(ScreenKeyboard.ResetMessage, 0, 0,, "ahk_id " hwnd)
    }

    Receive(sender, data, *) {
        if NumGet(data, 0, "UPtr") != ScreenKeyboard.Protocol
            return
        if !this.Pid || WinGetPID("ahk_id " sender) != this.Pid
            return 0
        request := JsonGo.Parse(StrGet(NumGet(data, 2 * A_PtrSize, "Ptr"), "UTF-16"))
        this.Queue.Push({Request: request, Hwnd: WinExist("A")})
        if !this.Busy
            SetTimer(this.Draining, -1)
        return 1
    }

    Drain() {
        if this.Busy
            return
        this.Busy := true
        try {
            while this.Queue.Length {
                event := this.Queue.RemoveAt(1)
                ; 已切走的目标不接收排队中的输入，菜单关闭后的 reset 仍需执行。
                if event.Request["command"] == "reset" || event.Hwnd == WinExist("A")
                    this.Input.Handle(event.Request, event.Hwnd)
            }
        } finally {
            this.Busy := false
            if this.Queue.Length
                SetTimer(this.Draining, -1)
        }
    }

    Open(*) {
        if this.Pid && ProcessExist(this.Pid) {
            if hwnd := WinExist("ahk_pid " this.Pid)
                PostMessage(ScreenKeyboard.ShowMessage, 0, 0,, "ahk_id " hwnd)
            return this.Pid
        }
        this.Pid := this.Python.Launch(this.Root "\py\main.py", ["screen-keyboard", "--host", A_ScriptHwnd], this.Root)
        return this.Pid
    }

    Stop() {
        SetTimer(this.Draining, 0)
        this.Queue := []
        if this.HasOwnProp("Input")
            this.Input.ResetInput()
        if this.Pid && ProcessExist(this.Pid) {
            if hwnd := WinExist("ahk_pid " this.Pid)
                PostMessage(0x0010, 0, 0,, "ahk_id " hwnd)
            else
                ProcessClose(this.Pid)
        }
        this.Pid := 0
    }
}
