class WindowActions {
    static DefaultWidth := 1000
    static DefaultHeight := 800
    static PassOpacity := 150
    static PassHwnd := 0

    static Center(reset, context) {
        if !WindowGroups.Matches(WindowGroups.WindowFixed, context.Hwnd)
            WindowTools.Center(context.Hwnd, reset ? this.DefaultWidth : 0, reset ? this.DefaultHeight : 0)
    }
    static CycleOpacity(context) => WindowTools.CycleOpacity(context.Hwnd)
    static ShowDesktop(*) => WindowTools.ShowDesktop()
    static MinimizeOthers(context) => WindowTools.MinimizeOthers(context.Hwnd)

    static TogglePassThrough(context) {
        if this.PassHwnd
            this.Stop()
        else if !WindowGroups.Matches(WindowGroups.WindowFixed, context.Hwnd) {
            this.PassHwnd := context.Hwnd
            WindowTools.PassThrough(this.PassHwnd, true, this.PassOpacity)
        }
    }

    static Stop(*) {
        if this.PassHwnd && WinExist("ahk_id " this.PassHwnd)
            WindowTools.PassThrough(this.PassHwnd, false, this.PassOpacity)
        this.PassHwnd := 0
    }

    static WheelTransparency(delta, *) => this.AdjustTransparency(delta)

    static AdjustTransparency(delta, hwnd := 0) {
        if !(hwnd := hwnd ? hwnd : WinExist("A"))
            return
        target := "ahk_id " hwnd
        try {
            current := WinGetTransparent(target)
            current := current == "" ? 255 : current
            value := Min(255, Max(35, current + delta))
            WinSetTransparent(value == 255 ? "Off" : value, target)
        } catch TargetError {
            return
        }
    }
}
