; 使用一次性定时器自动隐藏，空闲时无轮询。
class TooltipPresenter {
    static LaunchDuration := 2000

    ShowLaunching(name) => this.Show("正在启动 " name "，请稍等…", TooltipPresenter.LaunchDuration)

    __New() {
        this.HideCallback := ObjBindMethod(this, "Hide")
    }

    Show(text, duration := 3000) {
        SetTimer(this.HideCallback, 0)
        ToolTip(text)
        SetTimer(this.HideCallback, -duration)
    }

    Hide(*) {
        SetTimer(this.HideCallback, 0)
        ToolTip()
    }
}
