class MouseSender {
    static PointSize := 8
    __New(sender) {
        this.Sender := sender
    }

    Middle(down) => this.Sender.Send(down ? "{MButton down}" : "{MButton up}")
    Scroll(direction, count := 1) => this.Sender.Send("{" direction " " count "}")
    ScrollUnmodified(direction, count := 1) => this.Sender.SendChord("{" direction " " count "}")
    Click(button, *) => this.Sender.Send("{" button "}")
    Move(dx, dy, *) {
        point := Buffer(MouseSender.PointSize)
        if !DllCall("GetPhysicalCursorPos", "Ptr", point)
            throw OSError()
        if !DllCall("SetPhysicalCursorPos", "Int", NumGet(point, 0, "Int") + dx,
            "Int", NumGet(point, 4, "Int") + dy)
            throw OSError()
    }
}
