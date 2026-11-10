; 按下时确定拖动按键，松开时逆序释放；不轮询鼠标或前台窗口。
class MiddleDragController {
    __New(sender, resolve, pressed := unset) {
        this.Sender := sender
        this.Resolve := resolve
        this.Pressed := IsSet(pressed) ? pressed : ObjBindMethod(this, "KeyPressed")
        this.Enabled := true
        this.Held := false
        this.Owned := []
    }

    CanHandle(*) => this.Held || (this.Enabled && this.Resolve.Call(WinExist("A")).Length)
    IsHeld(*) => this.Held
    Down(*) => this.Begin(WinExist("A"))
    KeyPressed(key, physicalOnly := false) => GetKeyState(key, "P") || (!physicalOnly && GetKeyState(key))

    Begin(hwnd) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Held
                return
            this.Held := true
            if !this.Enabled
                return
            keys := ""
            for key in this.Resolve.Call(hwnd) {
                if !this.Pressed.Call(key) {
                    this.Owned.Push(key)
                    keys .= "{" key " down}"
                }
            }
            if keys != ""
                this.Sender.Send(keys)
        } catch {
            this.Release()
            throw
        } finally Critical(previousCritical)
    }

    Up(*) {
        previousCritical := A_IsCritical
        Critical("On")
        try this.Release()
        finally {
            this.Held := false
            Critical(previousCritical)
        }
    }

    Release() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            keys := ""
            while this.Owned.Length {
                key := this.Owned.Pop()
                ; 用户随后实际按住的键，交回其物理抬起事件释放。
                if !this.Pressed.Call(key, true)
                    keys .= "{" key " up}"
            }
            if keys != ""
                this.Sender.Send(keys)
        } finally Critical(previousCritical)
    }

    SetEnabled(enabled) {
        this.Enabled := !!enabled
        if !enabled
            this.Release()
    }

    Stop() {
        this.SetEnabled(false)
        this.Held := false
    }

    ResetInput() {
        this.Release()
        this.Held := this.Held && this.Pressed.Call("MButton", true)
    }
}
