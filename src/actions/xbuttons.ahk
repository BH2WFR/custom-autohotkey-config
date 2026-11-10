; 侧键按下/抬起配对；暂停或切换前台窗口后仍收尾已捕获的抬起。
class XButtonController {
    static Back := "XButton1"
    static Forward := "XButton2"
    static ErrorDuration := 1800

    __New(actions, tooltip, mappingEnabled := true) {
        this.Actions := actions
        this.Tooltip := tooltip
        this.Enabled := true
        this.MappingEnabled := !!mappingEnabled
        this.Held := Map()
        this.Busy := false
    }

    CanHandle(key, *) => this.Held.Has(key) || (this.IsEnabled() && this.Actions.CanHandle(WinExist("A")))
    IsHeld(key, *) => this.Held.Has(key)
    IsEnabled(*) => this.Enabled && this.MappingEnabled

    Down(key, mode, *) {
        if this.Held.Has(key)
            return
        this.Held[key] := true
        if !this.IsEnabled() || this.Busy
            return
        hwnd := WinExist("A")
        if !this.Actions.CanHandle(hwnd)
            return
        this.Busy := true
        try this.Actions.Execute(hwnd, key == XButtonController.Back, mode, ObjBindMethod(this, "IsEnabled"))
        catch Error as err
            this.Tooltip.Show(err.Message, XButtonController.ErrorDuration)
        finally this.Busy := false
    }

    Up(key, *) {
        if this.Held.Has(key)
            this.Held.Delete(key)
    }

    SetEnabled(enabled) => this.Enabled := !!enabled
    SetMappingEnabled(enabled) => this.MappingEnabled := !!enabled
    ResetInput() {
        for key in this.Held.Clone() {
            if !GetKeyState(key, "P")
                this.Up(key)
        }
    }

    Stop() {
        this.Enabled := false
        this.Held.Clear()
    }
}
