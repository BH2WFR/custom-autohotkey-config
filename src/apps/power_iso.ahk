class PowerIsoActions {
    static Back := {X: 20, Y: 108}
    static Forward := {X: 60, Y: 108}

    __New(automation) {
        this.Automation := automation
    }

    Navigate(hwnd, back, allowed) => this.Automation.Run(hwnd, [back ? PowerIsoActions.Back : PowerIsoActions.Forward], allowed)
}
