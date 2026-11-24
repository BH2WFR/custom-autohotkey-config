; 96 DPI 窗口相对坐标与物理屏幕坐标换算。
class WindowGeometry {
    static PerMonitorV2 := -4
    static NearestMonitor := 2
    static RectBytes := 16
    static PercentBase := 100

    static Measure(hwnd) {
        previousCritical := A_IsCritical
        Critical("On")
        previousContext := DllCall("SetThreadDpiAwarenessContext", "Ptr", this.PerMonitorV2, "Ptr")
        try {
            if !previousContext
                throw OSError()
            rect := Buffer(this.RectBytes)
            if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
                throw OSError()
            monitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", this.NearestMonitor, "Ptr")
            ; GetDpiForWindow 对 DPI unaware 程序返回 96；模板需要窗口所在显示器的实际缩放。
            ; https://learn.microsoft.com/windows/win32/api/shellscalingapi/nf-shellscalingapi-getscalefactorformonitor
            percent := 0
            result := DllCall("Shcore\GetScaleFactorForMonitor", "Ptr", monitor, "Int*", &percent, "Int")
            if result < 0
                throw OSError(result)
            return {X: NumGet(rect, 0, "Int"), Y: NumGet(rect, 4, "Int"),
                Width: NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int"),
                Height: NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int"), Scale: percent / this.PercentBase}
        } finally {
            if previousContext
                DllCall("SetThreadDpiAwarenessContext", "Ptr", previousContext, "Ptr")
            Critical(previousCritical)
        }
    }

    static ToScreen(bounds, x, y) {
        dx := Round(x * bounds.Scale), dy := Round(y * bounds.Scale)
        if dx < 0 || dy < 0 || dx >= bounds.Width || dy >= bounds.Height
            throw ValueError("点击位置超出窗口范围。")
        return {X: bounds.X + dx, Y: bounds.Y + dy}
    }
}
