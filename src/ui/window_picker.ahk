; 参考 WinSpy 的鼠标捕获与四边框方案；只在拖动消息到来时更新。
class WindowPickerView {
    static MouseDown := 0x0201
    static MouseMove := 0x0200
    static MouseLeave := 0x02A3
    static TrackLeave := 2
    static TipId := 2
    static Hint := "将此小圆饼拖动到目标窗口，即可查看窗口信息"
    static MouseUp := 0x0202
    static CaptureChanged := 0x0215
    static CancelMode := 0x001F
    static SetCursorMessage := 0x0020
    static CrossCursor := 32515
    Dragging := false
    Target := 0
    Hovering := false

    __New(gui, control, hitTest, selected, status) {
        this.Owner := gui.Hwnd, this.Control := control.Hwnd
        this.HitTest := hitTest, this.Selected := selected, this.Status := status
        this.Border := WindowHighlightView()
        this.Cursor := DllCall("LoadCursorW", "Ptr", 0, "Ptr", WindowPickerView.CrossCursor, "Ptr")
        this.Handlers := Map()
        for message in [WindowPickerView.MouseDown, WindowPickerView.MouseMove, WindowPickerView.MouseUp,
            WindowPickerView.MouseLeave, WindowPickerView.CaptureChanged, WindowPickerView.CancelMode, WindowPickerView.SetCursorMessage] {
            callback := ObjBindMethod(this, "Message")
            this.Handlers[message] := callback
            OnMessage(message, callback)
        }
    }

    Message(wParam, lParam, message, hwnd) {
        if hwnd == this.Control {
            if message == WindowPickerView.MouseMove && !this.Dragging && !this.Hovering {
                tracking := Buffer(8 + 2 * A_PtrSize, 0)
                NumPut("UInt", tracking.Size, "UInt", WindowPickerView.TrackLeave, "Ptr", hwnd, tracking)
                if DllCall("TrackMouseEvent", "Ptr", tracking) {
                    this.Hovering := true
                    ToolTip(WindowPickerView.Hint,,, WindowPickerView.TipId)
                }
            } else if message == WindowPickerView.MouseLeave
                this.HideHint()
        }
        if message == WindowPickerView.MouseDown {
            if hwnd != this.Control
                return
            this.Border.Hide()
            this.HideHint()
            this.Dragging := true, this.Target := 0
            DllCall("SetCapture", "Ptr", this.Owner)
            this.OldCursor := DllCall("SetCursor", "Ptr", this.Cursor, "Ptr")
            this.Status.Call("拖动到目标窗口后松开；Esc 取消")
            return 0
        }
        if !this.Dragging || hwnd != this.Owner
            return
        switch message {
            case WindowPickerView.MouseMove:
                try this.Update()
                catch Error as err {
                    this.Cancel()
                    this.Status.Call(err.Message)
                }
                return 0
            case WindowPickerView.MouseUp:
                target := 0
                try {
                    this.Update()
                    target := this.Target
                } catch Error as err {
                    this.Status.Call(err.Message)
                } finally this.Cancel()
                if target
                    this.Selected.Call(target)
                return 0
            case WindowPickerView.SetCursorMessage:
                DllCall("SetCursor", "Ptr", this.Cursor)
                return true
            case WindowPickerView.CaptureChanged, WindowPickerView.CancelMode:
                this.Cancel()
        }
    }

    HideHint() {
        if this.Hovering {
            ToolTip(,,, WindowPickerView.TipId)
            this.Hovering := false
        }
    }

    Update() {
        hwnd := this.HitTest.Call()
        if this.Border.Contains(hwnd)
            return
        if hwnd == this.Owner
            hwnd := 0
        if hwnd == this.Target
            return
        this.Target := hwnd
        if hwnd {
            this.Border.Show(hwnd)
            this.Status.Call("目标 HWND：" WindowInfo.Hex(hwnd) "；松开读取窗口信息")
        } else
            this.Border.Hide()
    }

    Cancel() {
        if this.Dragging {
            this.Dragging := false
            if DllCall("GetCapture", "Ptr") == this.Owner
                DllCall("ReleaseCapture")
            DllCall("SetCursor", "Ptr", this.OldCursor)
        }
        this.Border.Hide()
        this.Target := 0
    }

    Destroy() {
        this.HideHint()
        this.Cancel()
        for message, callback in this.Handlers
            OnMessage(message, callback, 0)
        this.Handlers.Clear()
        this.Border.Destroy()
    }
}

class WindowHighlightView {
    static Thickness := 4
    static Color := "FF4422"
    static ShowNoActivate := 0x0040 | 0x0010

    __New() {
        this.Edges := []
        this.HideTimer := ObjBindMethod(this, "Hide")
        loop 4 {
            edge := Gui("-Caption +ToolWindow +AlwaysOnTop -DPIScale +E0x08080020")
            edge.BackColor := WindowHighlightView.Color
            WinSetTransparent(255, edge.Hwnd)
            this.Edges.Push(edge)
        }
    }

    Contains(hwnd) {
        for edge in this.Edges
            if edge.Hwnd == hwnd
                return true
        return false
    }

    Show(hwnd, duration := 0) {
        if duration
            this.Hide()
        b := WindowGeometry.VisibleFrame(hwnd)
        r := Max(1, Round(WindowHighlightView.Thickness * b.Scale))
        x := b.X, y := b.Y, w := b.Width, h := b.Height
        dx := Min(r, w), dy := Min(r, h)
        rectangles := [[x, y, w, dy], [x, y + h - dy, w, dy], [x, y, dx, h], [x + w - dx, y, dx, h]]
        previousCritical := A_IsCritical
        Critical("On")
        previous := DllCall("SetThreadDpiAwarenessContext", "Ptr", WindowGeometry.PerMonitorV2, "Ptr")
        try {
            for index, rect in rectangles
                if !DllCall("SetWindowPos", "Ptr", this.Edges[index].Hwnd, "Ptr", -1,
                    "Int", rect[1], "Int", rect[2], "Int", rect[3], "Int", rect[4], "UInt", WindowHighlightView.ShowNoActivate)
                    throw OSError()
            if duration
                SetTimer(this.HideTimer, -duration)
        } catch as err {
            this.Hide()
            throw err
        } finally {
            DllCall("SetThreadDpiAwarenessContext", "Ptr", previous, "Ptr")
            Critical(previousCritical)
        }
    }

    Hide() {
        SetTimer(this.HideTimer, 0)
        for edge in this.Edges
            edge.Hide()
    }

    Destroy() {
        SetTimer(this.HideTimer, 0)
        this.HideTimer := 0
        for edge in this.Edges
            edge.Destroy()
        this.Edges := []
    }
}
