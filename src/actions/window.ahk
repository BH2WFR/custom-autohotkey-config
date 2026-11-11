class WindowActions {
    static DefaultWidth := 1000
    static DefaultHeight := 800
    static PassOpacity := 150
    static TipDuration := 800
    static PassTipDuration := 1200
    static TitleMaxWidth := 250
    PassHwnd := 0

    __New(tooltip) {
        this.Tooltip := tooltip
    }

    Center(reset, context) {
        if !this.CanAdjust(context.Hwnd)
            return
        WindowTools.Center(context.Hwnd, reset ? WindowActions.DefaultWidth : 0, reset ? WindowActions.DefaultHeight : 0)
        this.Tooltip.Show(reset ? "重置窗口大小并居中" : "窗口居中", WindowActions.TipDuration)
    }
    CycleOpacity(context) {
        if !this.CanAdjust(context.Hwnd)
            return
        WindowTools.CycleOpacity(context.Hwnd)
        alpha := WinGetTransparent("ahk_id " context.Hwnd)
        percent := alpha == "" ? 100 : Round(alpha / WindowTools.Opaque * 100)
        this.ShowWindowTip("窗口不透明度：" percent "%", context.Hwnd, WindowActions.TipDuration)
    }
    ToggleTopmost(context) {
        if !this.CanAdjust(context.Hwnd)
            return
        enabled := WindowTools.ToggleTopmost(context.Hwnd)
        this.ShowWindowTip(enabled ? "已置顶当前窗口" : "已取消窗口置顶", context.Hwnd, WindowActions.TipDuration)
    }
    ShowDesktop(*) {
        WindowTools.ShowDesktop()
        this.Tooltip.Show("显示桌面", WindowActions.TipDuration)
    }
    MinimizeOthers(context) {
        WindowTools.MinimizeOthers(context.Hwnd)
        this.Tooltip.Show("最小化其他窗口", WindowActions.TipDuration)
    }

    TogglePassThrough(context) {
        if this.PassHwnd {
            hwnd := this.PassHwnd
            this.Stop()
            this.ShowWindowTip("已关闭窗口穿透", hwnd, WindowActions.PassTipDuration)
        }
        else if this.CanAdjust(context.Hwnd) {
            this.PassHwnd := context.Hwnd
            WindowTools.PassThrough(this.PassHwnd, true, WindowActions.PassOpacity)
            this.ShowWindowTip("已开启窗口穿透，再按一次恢复", this.PassHwnd, WindowActions.PassTipDuration)
        }
    }

    Stop(*) {
        if this.PassHwnd && WinExist("ahk_id " this.PassHwnd)
            WindowTools.PassThrough(this.PassHwnd, false, WindowActions.PassOpacity)
        this.PassHwnd := 0
    }

    WheelTransparency(delta, *) {
        if !(hwnd := WinExist("A"))
            return
        if !this.CanAdjust(hwnd)
            return
        value := WindowActions.AdjustTransparency(delta, hwnd)
        if IsNumber(value)
            this.ShowWindowTip("窗口不透明度：" Round(value / WindowTools.Opaque * 100) "%", hwnd, WindowActions.TipDuration)
    }

    CanAdjust(hwnd) {
        if !WindowGroups.Matches(WindowGroups.WindowFixed, hwnd)
            return true
        this.ShowWindowTip("不可以调整这个窗口", hwnd, WindowActions.TipDuration)
        return false
    }

    ShowWindowTip(message, hwnd, duration) {
        title := ""
        try title := WinGetTitle("ahk_id " hwnd)
        catch TargetError {
        }
        this.Tooltip.ShowWithDetail(message, title, WindowActions.TitleMaxWidth, duration)
    }

    static AdjustTransparency(delta, hwnd := 0) {
        if !(hwnd := hwnd ? hwnd : WinExist("A"))
            return
        if WindowGroups.Matches(WindowGroups.WindowFixed, hwnd)
            return
        target := "ahk_id " hwnd
        try {
            current := WinGetTransparent(target)
            current := current == "" ? 255 : current
            value := Min(255, Max(35, current + delta))
            WinSetTransparent(value == 255 ? "Off" : value, target)
            return value
        } catch TargetError {
            return
        }
    }
}
