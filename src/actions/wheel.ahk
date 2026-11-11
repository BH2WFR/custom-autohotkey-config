; 滚轮动作；窗口类别与触发条件由 rules 层决定。
class WheelActions {
    static TipDuration := 500

    __New(mouse, sender, tooltip, settings) {
        this.Mouse := mouse
        this.Sender := sender
        this.Tooltip := tooltip
        this.Settings := settings
    }

    CapsScroll(up, context) {
        horizontal := context.Layer == 2
        direction := horizontal ? (up ? "WheelLeft" : "WheelRight") : (up ? "WheelUp" : "WheelDown")
        ; 连续操作保留层，只在发送期间移除 Shift 等修饰键。
        this.Mouse.ScrollUnmodified(direction, horizontal ? 1 : this.Settings.wheelMultiplier)
        this.Tooltip.Show(horizontal ? (up ? "向左横向滚动" : "向右横向滚动") : (up ? "快速向上滚动" : "快速向下滚动"), WheelActions.TipDuration)
    }

    Horizontal(left, *) {
        this.Mouse.ScrollUnmodified(left ? "WheelLeft" : "WheelRight")
        this.Tooltip.Show(left ? "向左横向滚动" : "向右横向滚动", WheelActions.TipDuration)
    }
    Volume(up, *) => this.Sender.Send(up ? "{Volume_Up}" : "{Volume_Down}")
}
