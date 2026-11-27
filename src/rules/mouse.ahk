; 项目鼠标热键声明。
class MouseBindings {
    static Register(native, mouse, xbuttons, middleDrag, input, wheel, windows) {
        native.Add("MButton", ObjBindMethod(middleDrag, "Down"), ObjBindMethod(middleDrag, "CanHandle"))
        native.Add("*MButton up", ObjBindMethod(middleDrag, "Up"), ObjBindMethod(middleDrag, "IsHeld"))
        for key in [XButtonController.Back, XButtonController.Forward] {
            for prefix, mode in Map("", XButtonActions.Normal, "+", XButtonActions.Raw,
                "^", XButtonActions.Ignore, "^+", XButtonActions.Ignore, "#", XButtonActions.Desktop)
                native.Add(prefix key, ObjBindMethod(xbuttons, "Down", key, mode), ObjBindMethod(xbuttons, "CanHandle", key))
            native.Add("*" key " up", ObjBindMethod(xbuttons, "Up", key), ObjBindMethod(xbuttons, "IsHeld", key))
        }
        native.Add("*F2", ObjBindMethod(mouse, "MiddleKeyDown", "F2"), ObjBindMethod(mouse, "CanHandle", "F2"))
        for key, direction in Map("F3", "WheelUp", "F4", "WheelDown")
            native.Add("*" key, ObjBindMethod(mouse, "ScrollKeyDown", key, direction), ObjBindMethod(mouse, "CanHandle", key))
        for key in ["F2", "F3", "F4"]
            native.Add("*" key " up", ObjBindMethod(mouse, "KeyUp", key), ObjBindMethod(mouse, "IsHeld", key))
        addWheel(key, route, action, condition) {
            native.Add("*" key, ObjBindMethod(input.Wheel, "Dispatch", key, route, action), condition)
        }
        for direction in ["WheelLeft", "WheelRight"]
            addWheel(direction, "reverse", ObjBindMethod(mouse, "Horizontal", direction), ObjBindMethod(mouse, "ReverseEnabled"))
        for key, up in Map("WheelUp", true, "WheelDown", false) {
            capsAvailable := ObjBindMethod(input, "CanHandle", key)
            addWheel(key, WheelPolicy.Window, ObjBindMethod(windows, "WheelTransparency", up ? WheelPolicy.TransparencyStep : -WheelPolicy.TransparencyStep),
                ObjBindMethod(WheelPolicy, "Transparency", mouse, capsAvailable))
            addWheel(key, WheelPolicy.Volume, ObjBindMethod(wheel, "Volume", up), ObjBindMethod(WheelPolicy, "Taskbar", mouse, capsAvailable))
        }
    }
}
