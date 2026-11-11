; Layer 滚轮优先，其次 Win 透明度，最后无修饰键的任务栏音量。
class WheelPolicy {
    static TransparencyStep := 20
    static Caps := "caps"
    static Window := "window"
    static Volume := "volume"
    static Native := "native"

    static Resolve(capsAvailable, transparencyEnabled, modifiers, overTaskbar) {
        if capsAvailable
            return this.Caps
        win := modifiers.Get("LWin", false) || modifiers.Get("RWin", false)
        for key, down in modifiers {
            if down && key != "LWin" && key != "RWin"
                return this.Native
        }
        if win
            return transparencyEnabled ? this.Window : this.Native
        return overTaskbar ? this.Volume : this.Native
    }

    static Transparency(mouse, capsAvailable, *) {
        return mouse.TransparencyEnabled()
            && this.Resolve(capsAvailable.Call(), true, KeyboardSender.ReadModifiers(), false) == this.Window
    }

    static Taskbar(mouse, capsAvailable, *) {
        if !mouse.Enabled || capsAvailable.Call()
            return false
        for key, down in KeyboardSender.ReadModifiers() {
            if down
                return false
        }
        MouseGetPos(,, &hwnd)
        return WindowGroups.Matches(WindowGroups.Taskbar, hwnd)
    }
}
