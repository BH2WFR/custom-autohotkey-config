class PointerActions {
    static Step := 1
    __New(mouse, settings) {
        this.Mouse := mouse
        this.Settings := settings
    }
    Move(dx, dy, context) {
        shift := context.Modifiers.Get("LShift", false) || context.Modifiers.Get("RShift", false)
        step := shift ? this.Settings.pointerFastStep : PointerActions.Step
        this.Mouse.Move(dx * step, dy * step)
    }
}
