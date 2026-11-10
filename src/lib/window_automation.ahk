; 通用窗口点击序列；应用坐标、版本和菜单布局由调用者提供。
class WindowAutomation {
    static StepDelay := 30
    static PointBytes := 8

    __New(sender) {
        this.Sender := sender
    }

    Run(hwnd, steps, allowed) {
        if !allowed.Call() || !WinActive("ahk_id " hwnd)
            return false
        saved := Buffer(WindowAutomation.PointBytes)
        if !DllCall("GetPhysicalCursorPos", "Ptr", saved)
            throw OSError()
        try {
            bounds := WindowGeometry.Measure(hwnd)
            ; 在首个点击之前检查完整序列。
            for step in steps {
                if step.HasOwnProp("X")
                    WindowGeometry.ToScreen(bounds, step.X, step.Y)
            }
            for step in steps {
                if !allowed.Call() || !WinActive("ahk_id " hwnd)
                    return false
                if step.HasOwnProp("X") {
                    point := WindowGeometry.ToScreen(WindowGeometry.Measure(hwnd), step.X, step.Y)
                    if !DllCall("SetPhysicalCursorPos", "Int", point.X, "Int", point.Y)
                        throw OSError()
                    this.Sender.SendChord("{Click}")
                } else
                    this.Sender.SendChord(step.Keys)
                Sleep(WindowAutomation.StepDelay)
            }
            return true
        } finally DllCall("SetPhysicalCursorPos", "Int", NumGet(saved, 0, "Int"), "Int", NumGet(saved, 4, "Int"))
    }

    ClickControl(hwnd, control) => ControlClick(control, "ahk_id " hwnd,,,, "NA")
}
