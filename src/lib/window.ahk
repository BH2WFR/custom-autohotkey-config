; 基础窗口操作，不维护应用分类或功能状态。
class WindowTools {
    static MonitorInfoSize := 40
    static WorkAreaOffset := 20
    static TransparentStyle := 0x20
    static Opaque := 255
    static OpacityLevels := [51, 102, 153, 204, 255]

    static Center(hwnd, width := 0, height := 0) {
        target := "ahk_id " hwnd
        WinRestore(target)
        previousCritical := A_IsCritical
        Critical("On")
        previous := DllCall("SetThreadDpiAwarenessContext", "Ptr", WindowGeometry.PerMonitorV2, "Ptr")
        try {
            bounds := WindowGeometry.Measure(hwnd)
            monitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", WindowGeometry.NearestMonitor, "Ptr")
            info := Buffer(this.MonitorInfoSize)
            NumPut("UInt", info.Size, info)
            if !DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
                throw OSError()
            left := NumGet(info, this.WorkAreaOffset, "Int"), top := NumGet(info, this.WorkAreaOffset + 4, "Int")
            availableWidth := NumGet(info, this.WorkAreaOffset + 8, "Int") - left
            availableHeight := NumGet(info, this.WorkAreaOffset + 12, "Int") - top
            width := Min(availableWidth, width ? Round(width * bounds.Scale) : bounds.Width)
            height := Min(availableHeight, height ? Round(height * bounds.Scale) : bounds.Height)
            WinMove(left + (availableWidth - width) // 2, top + (availableHeight - height) // 2, width, height, target)
        } finally {
            DllCall("SetThreadDpiAwarenessContext", "Ptr", previous, "Ptr")
            Critical(previousCritical)
        }
    }
    static NextOpacity(current) {
        if current == ""
            current := this.Opaque
        for index, value in this.OpacityLevels {
            if current == value
                return this.OpacityLevels[Mod(index, this.OpacityLevels.Length) + 1]
        }
        return this.Opaque
    }
    static CycleOpacity(hwnd) {
        target := "ahk_id " hwnd
        value := this.NextOpacity(WinGetTransparent(target))
        WinSetTransparent(value == this.Opaque ? "Off" : value, target)
    }
    static PassThrough(hwnd, enabled, opacity) {
        target := "ahk_id " hwnd
        WinSetAlwaysOnTop(enabled, target)
        if enabled {
            if WinGetTransparent(target) == "" || WinGetTransparent(target) == this.Opaque
                WinSetTransparent(opacity, target)
            WinSetExStyle("+" this.TransparentStyle, target)
        } else {
            WinSetExStyle("-" this.TransparentStyle, target)
            WinSetTransparent("Off", target)
        }
    }
    static ShowDesktop() => WinMinimizeAll()
    static MinimizeOthers(hwnd) {
        WinMinimizeAll()
        WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
    }
}
