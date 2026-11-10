; 滚轮动作；窗口类别与触发条件由 rules 层决定。
class WheelActions {
    static QuickSteps := 5

    __New(mouse, sender) {
        this.Mouse := mouse
        this.Sender := sender
    }

    CapsScroll(up, context) {
        horizontal := context.Layer == 2
        direction := horizontal ? (up ? "WheelLeft" : "WheelRight") : (up ? "WheelUp" : "WheelDown")
        ; 连续操作保留层，只在发送期间移除 Shift 等修饰键。
        this.Mouse.ScrollUnmodified(direction, horizontal ? 1 : WheelActions.QuickSteps)
    }

    Horizontal(left, *) => this.Mouse.Scroll(left ? "WheelLeft" : "WheelRight")
    Volume(up, *) => this.Sender.Send(up ? "{Volume_Up}" : "{Volume_Down}")
}
