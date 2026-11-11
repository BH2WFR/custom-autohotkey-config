; 参考 WinSpy 的鼠标捕获与四边框方案；只在拖动消息到来时更新。
class WindowPickerView {
    static MouseDown := 0x0201
    static MouseMove := 0x0200
    static MouseUp := 0x0202
    static CaptureChanged := 0x0215
    static CancelMode := 0x001F
    static SetCursorMessage := 0x0020
    static CrossCursor := 32515
    Dragging := false
    Target := 0

    __New(gui, control, hitTest, selected, status) {
        this.Owner := gui.Hwnd, this.Control := control.Hwnd
        this.HitTest := hitTest, this.Selected := selected, this.Status := status
        this.Border := WindowHighlightView()
        this.Cursor := DllCall("LoadCursorW", "Ptr", 0, "Ptr", WindowPickerView.CrossCursor, "Ptr")
        this.Handlers := Map()
        for message in [WindowPickerView.MouseDown, WindowPickerView.MouseMove, WindowPickerView.MouseUp,
            WindowPickerView.CaptureChanged, WindowPickerView.CancelMode, WindowPickerView.SetCursorMessage] {
            callback := ObjBindMethod(this, "Message")
            this.Handlers[message] := callback
            OnMessage(message, callback)
        }
    }

    Message(wParam, lParam, message, hwnd) {
        if message == WindowPickerView.MouseDown {
            if hwnd != this.Control
                return
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

    Show(hwnd) {
        b := WindowGeometry.Measure(hwnd), r := Max(1, Round(WindowHighlightView.Thickness * b.Scale))
        rectangles := [[b.X - r, b.Y - r, b.Width + 2 * r, r], [b.X - r, b.Y + b.Height, b.Width + 2 * r, r],
            [b.X - r, b.Y, r, b.Height], [b.X + b.Width, b.Y, r, b.Height]]
        previousCritical := A_IsCritical
        Critical("On")
        previous := DllCall("SetThreadDpiAwarenessContext", "Ptr", WindowGeometry.PerMonitorV2, "Ptr")
        try {
            for index, rect in rectangles
                DllCall("SetWindowPos", "Ptr", this.Edges[index].Hwnd, "Ptr", -1,
                    "Int", rect[1], "Int", rect[2], "Int", rect[3], "Int", rect[4], "UInt", WindowHighlightView.ShowNoActivate)
        } finally {
            DllCall("SetThreadDpiAwarenessContext", "Ptr", previous, "Ptr")
            Critical(previousCritical)
        }
    }

    Hide() {
        for edge in this.Edges
            edge.Hide()
    }

    Destroy() {
        for edge in this.Edges
            edge.Destroy()
        this.Edges := []
    }
}
