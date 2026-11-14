class WindowActions {
    static DefaultWidth := 1000
    static DefaultHeight := 800
    static PassOpacity := 150
    static TipDuration := 800
    static PassTipDuration := 1200
    static ErrorDuration := 1800
    static TitleMaxWidth := 250
    PassHwnd := 0

    __New(tooltip) {
        this.Tooltip := tooltip
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
        alpha := WinGetTransparent("ahk_id " context.Hwnd)
        percent := alpha == "" ? 100 : Round(alpha / WindowTools.Opaque * 100)
        this.ShowWindowTip("窗口不透明度：" percent "%", context.Hwnd, WindowActions.TipDuration)
    }
    _ToggleTopmost(context) {
        if !this.CanAdjust(context.Hwnd)
            return
        enabled := WindowTools.ToggleTopmost(context.Hwnd)
        this.ShowWindowTip(enabled ? "已置顶当前窗口" : "已取消窗口置顶", context.Hwnd, WindowActions.TipDuration)
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
            hwnd := this.DisablePassThrough()
            this.ShowWindowTip("已关闭窗口穿透", hwnd, WindowActions.PassTipDuration)
        }
        else if this.CanAdjust(context.Hwnd) {
            this.PassHwnd := context.Hwnd
            try WindowTools.PassThrough(this.PassHwnd, true, WindowActions.PassOpacity)
            finally {
                if !DllCall("IsWindow", "Ptr", this.PassHwnd)
                    this.PassHwnd := 0
            }
            this.ShowWindowTip("已开启窗口穿透，再按一次恢复", this.PassHwnd, WindowActions.PassTipDuration)
        }
    }

    DisablePassThrough() {
        hwnd := this.PassHwnd
        if !hwnd
            return 0
        try {
            WindowTools.RequireWindow(hwnd)
            WindowTools.PassThrough(hwnd, false, WindowActions.PassOpacity)
            this.PassHwnd := 0
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
        if IsNumber(value)
            this.ShowWindowTip("窗口不透明度：" Round(value / WindowTools.Opaque * 100) "%", hwnd, WindowActions.TipDuration)
    }

    CanAdjust(hwnd) {
        WindowTools.RequireWindow(hwnd)
        if !WindowGroups.Matches(WindowGroups.WindowFixed, hwnd)
            return true
        this.ShowWindowTip("不可以调整这个窗口", hwnd, WindowActions.TipDuration)
        return false
    }

    ShowWindowTip(message, hwnd, duration) {
        title := WinGetTitle("ahk_id " hwnd)
        this.Tooltip.ShowWithDetail(message, title, WindowActions.TitleMaxWidth, duration)
    }

    static AdjustTransparency(delta, hwnd := 0) {
        hwnd := hwnd ? hwnd : WinExist("A")
        WindowTools.RequireWindow(hwnd)
        if WindowGroups.Matches(WindowGroups.WindowFixed, hwnd)
            return
        target := "ahk_id " hwnd
        current := WinGetTransparent(target)
        current := current == "" ? 255 : current
        value := Min(255, Max(35, current + delta))
        WinSetTransparent(value == 255 ? "Off" : value, target)
        return value
    }
}
