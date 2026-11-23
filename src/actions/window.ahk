class WindowActions {
    static DefaultWidth := 1000
    static DefaultHeight := 800
    PassOpacity => Round(this.Settings.passThroughOpacityPercent * WindowTools.Opaque / 100)
    static TipDuration := 800
    static PassTipDuration := 1200
    static ErrorDuration := 1800
    PassHwnd := 0

    __New(tooltip, settings, styleChanged := 0) {
        this.Tooltip := tooltip
        this.Settings := settings
        this.StyleChanged := styleChanged
    }

    NotifyStyleChanged(hwnd) {
        if this.StyleChanged
            this.StyleChanged.Call(hwnd)
    }

    ; 所有入口共用错误提示，基础窗口库继续抛出原始异常。
    Run(operation, action, args*) {
        try {
            action.Call(args*)
            return true
        } catch Error as err {
            this.Tooltip.Show(operation "失败：" err.Message, WindowActions.ErrorDuration)
            return false
        }
    }

    Center(reset, context) => this.Run(reset ? "重置窗口大小" : "窗口居中", ObjBindMethod(this, "_Center"), reset, context)
    CycleOpacity(context) => this.Run("调整窗口透明度", ObjBindMethod(this, "_CycleOpacity"), context)
    ToggleTopmost(context) => this.Run("切换窗口置顶", ObjBindMethod(this, "_ToggleTopmost"), context)
    ShowDesktop(*) => this.Run("显示桌面", ObjBindMethod(this, "_ShowDesktop"))
    MinimizeOthers(context) => this.Run("最小化其他窗口", ObjBindMethod(this, "_MinimizeOthers"), context)
    TogglePassThrough(context) => this.Run("切换窗口穿透", ObjBindMethod(this, "_TogglePassThrough"), context)
    WheelTransparency(delta, *) => this.Run("调整窗口透明度", ObjBindMethod(this, "_WheelTransparency"), delta)
    Stop(*) => this.Run("关闭窗口穿透", ObjBindMethod(this, "DisablePassThrough"))

    _Center(reset, context) {
        if !this.CanAdjust(context.Hwnd)
            return
        WindowTools.Center(context.Hwnd, reset ? WindowActions.DefaultWidth : 0, reset ? WindowActions.DefaultHeight : 0)
        this.Tooltip.Show(reset ? "重置窗口大小并居中" : "窗口居中", WindowActions.TipDuration)
    }
    _CycleOpacity(context) {
        if !this.CanAdjust(context.Hwnd)
            return
        WindowTools.CycleOpacity(context.Hwnd)
        this.NotifyStyleChanged(context.Hwnd)
        percent := Round(WindowTools.GetOpacity(context.Hwnd) / WindowTools.Opaque * 100)
        this.Tooltip.Show("窗口不透明度：" percent "%", WindowActions.TipDuration)
    }
    _ToggleTopmost(context) {
        if !this.CanAdjust(context.Hwnd)
            return
        enabled := WindowTools.ToggleTopmost(context.Hwnd)
        this.NotifyStyleChanged(context.Hwnd)
        this.Tooltip.Show(enabled ? "已置顶当前窗口" : "已取消窗口置顶", WindowActions.TipDuration)
    }
    _ShowDesktop() {
        WindowTools.ShowDesktop()
        this.Tooltip.Show("显示桌面", WindowActions.TipDuration)
    }
    _MinimizeOthers(context) {
        WindowTools.MinimizeOthers(context.Hwnd)
        this.Tooltip.Show("最小化其他窗口", WindowActions.TipDuration)
    }

    _TogglePassThrough(context) {
        if this.PassHwnd {
            this.DisablePassThrough()
            this.Tooltip.Show("已关闭窗口穿透", WindowActions.PassTipDuration)
        }
        else if this.CanAdjust(context.Hwnd) {
            this.PassHwnd := context.Hwnd
            try WindowTools.PassThrough(this.PassHwnd, true, this.PassOpacity)
            finally {
                if !DllCall("IsWindow", "Ptr", this.PassHwnd)
                    this.PassHwnd := 0
            }
            this.NotifyStyleChanged(this.PassHwnd)
            this.Tooltip.Show("已开启窗口穿透`n再按一次恢复", WindowActions.PassTipDuration)
        }
    }

    DisablePassThrough() {
        hwnd := this.PassHwnd
        if !hwnd
            return 0
        try {
            WindowTools.RequireWindow(hwnd)
            WindowTools.PassThrough(hwnd, false, this.PassOpacity)
            this.PassHwnd := 0
            this.NotifyStyleChanged(hwnd)
            return hwnd
        } finally {
            ; 窗口关闭后清掉失效记录；仍存在的窗口保留记录以便再次关闭穿透。
            if !DllCall("IsWindow", "Ptr", hwnd)
                this.PassHwnd := 0
        }
    }

    _WheelTransparency(delta) {
        hwnd := WinExist("A")
        if !this.CanAdjust(hwnd)
            return
        value := WindowActions.AdjustTransparency(delta, hwnd)
        if IsNumber(value) {
            this.NotifyStyleChanged(hwnd)
            this.Tooltip.Show("窗口不透明度：" Round(value / WindowTools.Opaque * 100) "%", WindowActions.TipDuration)
        }
    }

    CanAdjust(hwnd) {
        WindowTools.RequireWindow(hwnd)
        if !WindowGroups.Matches(WindowGroups.WindowFixed, hwnd)
            return true
        this.Tooltip.Show("不可以调整这个窗口", WindowActions.TipDuration)
        return false
    }

    static AdjustTransparency(delta, hwnd := 0) {
        hwnd := hwnd ? hwnd : WinExist("A")
        WindowTools.RequireWindow(hwnd)
        if WindowGroups.Matches(WindowGroups.WindowFixed, hwnd)
            return
        current := WindowTools.GetOpacity(hwnd)
        value := Min(WindowTools.Opaque, Max(35, current + delta))
        WindowTools.SetOpacity(hwnd, value)
        return value
    }
}
