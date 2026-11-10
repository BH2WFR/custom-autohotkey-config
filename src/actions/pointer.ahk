class PointerActions {
    static Step := 1
    static FastStep := 5
    __New(mouse) {
        this.Mouse := mouse
    }
    Move(dx, dy, context) {
        shift := context.Modifiers.Get("LShift", false) || context.Modifiers.Get("RShift", false)
        step := shift ? PointerActions.FastStep : PointerActions.Step
        this.Mouse.Move(dx * step, dy * step)
    }
}
