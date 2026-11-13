; AHK 原生 GUI 的逐显示器缩放；视图以 96 DPI 声明布局。
class GuiDpi {
    static BaseDpi := 96
    static PerMonitorV2 := -4
    static ChangedMessage := 0x02E0
    static GetFontMessage := 0x0031
    static SetFontMessage := 0x0030
    static LogFontBytes := 92
    static KeepOrderAndFocus := 0x0014
    static NearestMonitor := 2
    static MonitorInfoBytes := 40

    static Enter() => DllCall("SetThreadDpiAwarenessContext", "Ptr", this.PerMonitorV2, "Ptr")
    static Leave(previous) => DllCall("SetThreadDpiAwarenessContext", "Ptr", previous, "Ptr")

    __New(gui, changed, minWidth, minHeight) {
        this.Gui := gui, this.Changed := changed
        this.MinWidth := minWidth, this.MinHeight := minHeight
        this.Scale := 1, this.Controls := [], this.Fonts := Map(), this.OwnFonts := []
        for control in gui {
            control.GetPos(&x, &y, &width, &height)
            font := SendMessage(GuiDpi.GetFontMessage, 0, 0, control.Hwnd)
            if font && !this.Fonts.Has(font) {
                data := Buffer(GuiDpi.LogFontBytes)
                DllCall("gdi32\GetObjectW", "Ptr", font, "Int", data.Size, "Ptr", data)
                this.Fonts[font] := data
            }
            this.Controls.Push({Control: control, X: x, Y: y, Width: width, Height: height, Font: font})
        }
        this.Handler := ObjBindMethod(this, "Message")
        OnMessage(GuiDpi.ChangedMessage, this.Handler)
    }

    Px(value) => Round(value * this.Scale)

    Apply(dpi) {
        previous := GuiDpi.Enter()
        try {
            this.Scale := dpi / GuiDpi.BaseDpi
            fonts := Map(), oldFonts := this.OwnFonts
            this.OwnFonts := []
            for original, data in this.Fonts {
                scaled := Buffer(data.Size)
                DllCall("RtlMoveMemory", "Ptr", scaled, "Ptr", data, "UPtr", data.Size)
                NumPut("Int", Round(NumGet(data, 0, "Int") * dpi / A_ScreenDPI), scaled)
                font := DllCall("gdi32\CreateFontIndirectW", "Ptr", scaled, "Ptr")
                fonts[original] := font
                this.OwnFonts.Push(font)
            }
            for item in this.Controls {
                if item.Font
                    SendMessage(GuiDpi.SetFontMessage, fonts[item.Font], true, item.Control.Hwnd)
                item.Control.Move(this.Px(item.X), this.Px(item.Y), this.Px(item.Width), this.Px(item.Height))
            }
            for font in oldFonts
                DllCall("gdi32\DeleteObject", "Ptr", font)
            this.Gui.Opt("+MinSize" this.Px(this.MinWidth) "x" this.Px(this.MinHeight))
        } finally GuiDpi.Leave(previous)
    }

    Message(wParam, lParam, message, hwnd) {
        if hwnd != this.Gui.Hwnd
            return
        this.Apply(wParam & 0xFFFF)
        previous := GuiDpi.Enter()
        try DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0,
            "Int", NumGet(lParam, 0, "Int"), "Int", NumGet(lParam, 4, "Int"),
            "Int", NumGet(lParam, 8, "Int") - NumGet(lParam, 0, "Int"),
            "Int", NumGet(lParam, 12, "Int") - NumGet(lParam, 4, "Int"),
            "UInt", GuiDpi.KeepOrderAndFocus)
        finally GuiDpi.Leave(previous)
        this.FitWindow()
        this.Changed.Call()
        return 0
    }

    FitWindow() {
        previous := GuiDpi.Enter()
        try {
            rect := Buffer(16), info := Buffer(GuiDpi.MonitorInfoBytes)
            DllCall("GetWindowRect", "Ptr", this.Gui.Hwnd, "Ptr", rect)
            monitor := DllCall("MonitorFromWindow", "Ptr", this.Gui.Hwnd, "UInt", GuiDpi.NearestMonitor, "Ptr")
            NumPut("UInt", info.Size, info)
            DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
            left := NumGet(info, 20, "Int"), top := NumGet(info, 24, "Int")
            right := NumGet(info, 28, "Int"), bottom := NumGet(info, 32, "Int")
            width := Min(right - left, NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int"))
            height := Min(bottom - top, NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int"))
            x := Max(left, Min(NumGet(rect, 0, "Int"), right - width))
            y := Max(top, Min(NumGet(rect, 4, "Int"), bottom - height))
            DllCall("SetWindowPos", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Int", x, "Int", y,
                "Int", width, "Int", height, "UInt", GuiDpi.KeepOrderAndFocus)
        } finally GuiDpi.Leave(previous)
    }

    Destroy() {
        OnMessage(GuiDpi.ChangedMessage, this.Handler, 0)
        for font in this.OwnFonts
            DllCall("gdi32\DeleteObject", "Ptr", font)
        this.OwnFonts := [], this.Controls := []
    }
}
