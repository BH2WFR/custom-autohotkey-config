class MouseController {
    __New(settings, actions) {
        this.Settings := settings
        this.Actions := actions
        this.Enabled := true
        this.FunctionKeys := false
        this.Held := Map()
        this.MiddleDown := false
    }

    CanHandle(key, *) => this.Held.Has(key) || (this.Enabled && this.FunctionKeys)
    IsHeld(key, *) => this.Held.Has(key)
    ReverseEnabled(*) => this.Enabled && this.Settings.reverseHorizontal
    TransparencyEnabled(*) => this.Enabled && this.Settings.winWheelTransparency

    MiddleKeyDown(key, *) {
        if this.Held.Has(key)
            return
        this.Held[key] := "middle"
        this.MiddleDown := true
        this.Actions.Middle(true)
    }

    ScrollKeyDown(key, direction, *) {
        if this.Held.Has(key)
            return
        this.Held[key] := "scroll"
        this.Actions.Scroll(direction)
    }

    KeyUp(key, *) {
        if this.Held.Has(key) && this.Held.Delete(key) == "middle"
            this.ReleaseMiddle()
    }

    ReleaseMiddle() {
        if this.MiddleDown {
            this.Actions.Middle(false)
            this.MiddleDown := false
        }
    }

    SetFunctionKeys(enabled) {
        this.FunctionKeys := !!enabled
        if !enabled
            this.ReleaseMiddle()
    }

    ToggleFunctionKeys(*) => this.SetFunctionKeys(!this.FunctionKeys)
    FunctionKeysEnabled(*) => this.FunctionKeys

    SetEnabled(enabled) {
        this.Enabled := !!enabled
        if !enabled
            this.ReleaseMiddle()
    }

    Horizontal(direction, count := 1) => this.Actions.Scroll(direction == "WheelLeft" ? "WheelRight" : "WheelLeft", count)

    ResetInput() {
        this.ReleaseMiddle()
        for key in this.Held.Clone() {
            if !GetKeyState(key, "P")
                this.KeyUp(key)
        }
    }

    Stop() {
        this.ReleaseMiddle()
        this.Held.Clear()
    }
}
