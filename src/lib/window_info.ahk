; 窗口快照与枚举，不包含界面、应用名单或运行状态。
class WindowInfo {
    static TextTimeout := 100
    static GetTextMessage := 0x000D
    static TextCapacity := 4096
    static RootAncestor := 2
    static ToolWindowStyle := 0x80
    static LayeredStyle := 0x80000
    static NoActivateStyle := 0x08000000
    static States := Map(-1, "最小化", 0, "正常", 1, "最大化")

    static Hex(value) => Format("0x{:08X}", value)

    static AtCursor() {
        point := Buffer(8)
        if !DllCall("GetPhysicalCursorPos", "Ptr", point)
            throw OSError()
        hwnd := DllCall("WindowFromPhysicalPoint", "Int64", NumGet(point, 0, "Int64"), "Ptr")
        ; GA_ROOT 保留独立弹窗；不能用 GA_ROOTOWNER 跳到广告的主窗口。
        return hwnd ? DllCall("GetAncestor", "Ptr", hwnd, "UInt", this.RootAncestor, "Ptr") : 0
    }

    static Find(query, hidden := false) {
        previousHidden := A_DetectHiddenWindows, previousMode := A_TitleMatchMode
        DetectHiddenWindows(hidden)
        SetTitleMatchMode(2)
        try {
            query := Trim(query)
            if query == ""
                return 0
            if RegExMatch(query, "i)^ID[:：]\s*(0x[0-9a-f]+|\d+)", &match)
                query := "ahk_id " match[1]
            else if RegExMatch(query, "i)^(0x[0-9a-f]+|\d+)$")
                query := "ahk_id " query
            return WinExist(query)
        } finally {
            DetectHiddenWindows(previousHidden)
            SetTitleMatchMode(previousMode)
        }
    }

    static List(hidden := false, exclude := 0) {
        previous := A_DetectHiddenWindows
        DetectHiddenWindows(hidden)
        try {
            result := []
            for hwnd in WinGetList() {
                if hwnd == exclude
                    continue
                try {
                    title := WinGetTitle("ahk_id " hwnd)
                    if title == ""
                        title := "Class: " WinGetClass("ahk_id " hwnd)
                    result.Push({Hwnd: hwnd, Label: "ID:" this.Hex(hwnd) ", " title})
                } catch TargetError {
                    continue
                }
            }
            return result
        } finally DetectHiddenWindows(previous)
    }

    static Read(hwnd) {
        previous := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try {
            target := "ahk_id " hwnd
            data := {Hwnd: hwnd, Title: WinGetTitle(target), Class: WinGetClass(target), Pid: WinGetPID(target)}
            data.ThreadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
            data.ProcessName := "", data.Path := ""
            try data.ProcessName := WinGetProcessName(target)
            try data.Path := WinGetProcessPath(target)
            data.Bounds := WindowGeometry.Measure(hwnd)
            data.Style := WinGetStyle(target), data.ExStyle := WinGetExStyle(target)
            data.Topmost := !!(data.ExStyle & WindowTools.TopmostStyle)
            data.ToolWindow := !!(data.ExStyle & this.ToolWindowStyle)
            data.Layered := !!(data.ExStyle & this.LayeredStyle)
            data.LayeredClickThrough := data.Layered && !!(data.ExStyle & WindowTools.TransparentStyle)
            data.NoActivate := !!(data.ExStyle & this.NoActivateStyle)
            alpha := WinGetTransparent(target)
            data.Opacity := alpha == "" ? 255 : alpha
            data.State := this.States[WinGetMinMax(target)]
            data.Parent := DllCall("GetParent", "Ptr", hwnd, "Ptr")
            data.ParentTitle := "", data.ParentClass := ""
            if data.Parent {
                try data.ParentTitle := WinGetTitle("ahk_id " data.Parent)
                try data.ParentClass := WinGetClass("ahk_id " data.Parent)
            }
            data.WindowCount := WinGetCount("ahk_pid " data.Pid)
            return data
        } finally DetectHiddenWindows(previous)
    }

    static Controls(hwnd) {
        previous := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try {
            target := "ahk_id " hwnd, result := []
            handles := WinGetControlsHwnd(target), names := WinGetControls(target)
            for index, control in handles {
                try {
                    bounds := WindowGeometry.Measure(control)
                    text := "", textBuffer := Buffer(this.TextCapacity * 2, 0)
                    try {
                        SendMessage(this.GetTextMessage, this.TextCapacity, textBuffer.Ptr, control,,,,, this.TextTimeout)
                        text := StrGet(textBuffer, "UTF-16")
                    }
                    result.Push({Hwnd: control, Name: names[index], Text: text,
                        Class: WinGetClass("ahk_id " control), Bounds: bounds})
                } catch TargetError {
                    continue
                }
            }
            return result
        } finally DetectHiddenWindows(previous)
    }
}
