; 双触点输入基础接口，使用物理屏幕坐标。
; https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-injecttouchinput
class TouchInjection {
    static Count := 2
    static TouchType := 2
    static FeedbackNone := 3
    static Down := 0x10006
    static Update := 0x20006
    static Up := 0x40000
    static Cancel := 0x48000
    static InfoSize := A_PtrSize == 8 ? 144 : 136
    static LocationOffset := 16 + 2 * A_PtrSize
    static FlagsOffset := 12
    static TouchMaskOffset := A_PtrSize == 8 ? 100 : 92
    static ContactOffset := A_PtrSize == 8 ? 104 : 96
    static ContactAreaMask := 0x1
    static ContactRadius := 2
    static PerMonitorV2 := -4
    static NearestMonitor := 2
    static MonitorInfoSize := 40
    static PointSize := 8
    static PercentBase := 100
    static NotReady := 21
    static RetryDelay := 1

    __New() => this.Initialized := false

    Initialize() {
        if this.Initialized
            return
        if !DllCall("InitializeTouchInjection", "UInt", TouchInjection.Count, "UInt", TouchInjection.FeedbackNone)
            throw OSError()
        this.Initialized := true
    }

    Send(points, flags) {
        packet := this.Packet(points, flags)
        if DllCall("InjectTouchInput", "UInt", TouchInjection.Count, "Ptr", packet)
            return
        errorCode := A_LastError
        ; 同一 0.1ms 时间片内的帧需原样重试，见 InjectTouchInput 文档。
        if errorCode != TouchInjection.NotReady
            throw OSError(errorCode)
        Sleep(TouchInjection.RetryDelay)
        if !DllCall("InjectTouchInput", "UInt", TouchInjection.Count, "Ptr", packet)
            throw OSError()
    }

    Packet(points, flags) {
        packet := Buffer(TouchInjection.InfoSize * TouchInjection.Count, 0)
        for index, point in points {
            ; 指针编号必须位于 InitializeTouchInjection(maxCount) 的范围内。
            id := index - 1
            offset := id * TouchInjection.InfoSize
            NumPut("UInt", TouchInjection.TouchType, "UInt", id, packet, offset)
            NumPut("UInt", flags, packet, offset + TouchInjection.FlagsOffset)
            NumPut("Int", point.X, "Int", point.Y, packet, offset + TouchInjection.LocationOffset)
            ; 沿用旧版的有效接触面积；零面积会扩大 Chromium 的点按容差，误判小幅缩放。
            NumPut("UInt", TouchInjection.ContactAreaMask, packet, offset + TouchInjection.TouchMaskOffset)
            radius := TouchInjection.ContactRadius
            NumPut("Int", point.X - radius, "Int", point.Y - radius,
                "Int", point.X + radius, "Int", point.Y + radius, packet, offset + TouchInjection.ContactOffset)
        }
        return packet
    }

    Position() {
        previousCritical := A_IsCritical
        Critical("On")
        dpi := DllCall("SetThreadDpiAwarenessContext", "Ptr", TouchInjection.PerMonitorV2, "Ptr")
        try {
            if !dpi
                throw OSError()
            point := Buffer(TouchInjection.PointSize)
            if !DllCall("GetPhysicalCursorPos", "Ptr", point)
                throw OSError()
            monitor := DllCall("MonitorFromPoint", "Int64", NumGet(point, 0, "Int64"), "UInt", TouchInjection.NearestMonitor, "Ptr")
            info := Buffer(TouchInjection.MonitorInfoSize, 0)
            NumPut("UInt", info.Size, info)
            if !DllCall("GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
                throw OSError()
            percent := 0
            result := DllCall("Shcore\GetScaleFactorForMonitor", "Ptr", monitor, "Int*", &percent, "Int")
            if result < 0
                throw OSError(result)
            return {X: NumGet(point, 0, "Int"), Y: NumGet(point, 4, "Int"),
                Left: NumGet(info, 4, "Int"), Top: NumGet(info, 8, "Int"),
                Right: NumGet(info, 12, "Int"), Bottom: NumGet(info, 16, "Int"), Scale: percent / TouchInjection.PercentBase}
        } finally {
            if dpi
                DllCall("SetThreadDpiAwarenessContext", "Ptr", dpi, "Ptr")
            Critical(previousCritical)
        }
    }

    Restore(position) => DllCall("SetPhysicalCursorPos", "Int", position.X, "Int", position.Y)
}
