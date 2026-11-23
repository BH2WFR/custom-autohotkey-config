; 基础窗口操作，不维护应用分类或功能状态。
class WindowTools {
    static MonitorInfoSize := 40
    static WorkAreaOffset := 20
    static TransparentStyle := 0x20
    static LayeredStyle := 0x80000
    static TopmostStyle := 0x8
    static MinimizeBoxStyle := 0x20000
    static Opaque := 255
    static OpacityLevels := [51, 102, 153, 204, 255]

    static RequireWindow(hwnd) {
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
            throw TargetError("目标窗口不存在或句柄已失效。")
    }

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
        this.SetOpacity(hwnd, this.NextOpacity(this.GetOpacity(hwnd)))
    }
    static GetOpacity(hwnd) {
        alpha := WinGetTransparent(hwnd)
        return alpha == "" ? this.Opaque : alpha
    }
    static SetOpacity(hwnd, alpha) {
        ; 穿透依赖分层窗口，即使完全不透明也要保留分层样式。
        if alpha == this.Opaque && !(WinGetExStyle(hwnd) & this.TransparentStyle)
            alpha := "Off"
        WinSetTransparent(alpha, hwnd)
    }
    static ToggleTopmost(hwnd) {
        enabled := !(WinGetExStyle(hwnd) & this.TopmostStyle)
        WinSetAlwaysOnTop(enabled, hwnd)
        return !!(WinGetExStyle(hwnd) & this.TopmostStyle)
    }
    static PassThrough(hwnd, enabled, opacity) {
        WinSetAlwaysOnTop(enabled, hwnd)
        if enabled {
            WinSetExStyle("+" this.TransparentStyle, hwnd)
            if this.GetOpacity(hwnd) == this.Opaque
                this.SetOpacity(hwnd, opacity)
        } else {
            WinSetExStyle("-" this.TransparentStyle, hwnd)
            this.SetOpacity(hwnd, this.Opaque)
        }
    }
    static ShowDesktop() => WinMinimizeAll()
    static MinimizeOrHide(hwnd) {
        if WinGetStyle(hwnd) & this.MinimizeBoxStyle
            WinMinimize(hwnd)
        else
            WinHide(hwnd)
    }
    static MinimizeOthers(hwnd) {
        this.RequireWindow(hwnd)
        WinMinimizeAll()
        WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
    }
}
