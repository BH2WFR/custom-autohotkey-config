; 屏幕键盘功能拥有自己的窗口与进程生命周期。
class ScreenKeyboard {
    __New(python, root) {
        this.Python := python
        this.Root := root
        this.Pid := 0
    }

    Open(*) {
        if this.Pid && ProcessExist(this.Pid) {
            if hwnd := WinExist("ahk_pid " this.Pid)
                WinActivate("ahk_id " hwnd)
            return this.Pid
        }
        this.Pid := this.Python.Launch(this.Root "\py\main.py", ["screen-keyboard"], this.Root)
        return this.Pid
    }

    Stop() {
        if this.Pid && ProcessExist(this.Pid) {
            if hwnd := WinExist("ahk_pid " this.Pid)
                PostMessage(0x0010, 0, 0,, "ahk_id " hwnd)
            else
                ProcessClose(this.Pid)
        }
        this.Pid := 0
    }
}
