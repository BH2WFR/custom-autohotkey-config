; 屏幕输入适配器复用注册表和分发器，独立持有会话，不伪造物理按键状态。
class VirtualKeyboardInput {
    static LayerKey := "F24"

    __New(registry, sender, resolve, tap) {
        this.Registry := registry
        this.Sender := sender
        this.Resolve := resolve
        this.Tap := tap
        this.State := LayerState()
        this.Dispatcher := HotkeyDispatcher(this.State, registry, sender)
        this.Enabled := true
        this.Target := 0
        this.Route := ""
        this.Used := false
    }

    Handle(request, hwnd) {
        if request["command"] == "reset" {
            this.ResetInput()
            return
        }
        if !this.Enabled || A_IsSuspended || !hwnd
            return
        if this.Target && hwnd != this.Target
            this.ResetInput()
        modifiers := KeyboardSender.ReadModifiers()
        for key in request["modifiers"]
            modifiers[key] := true
        switch request["command"] {
            case "begin":
                this.Target := hwnd
                this.Route := this.Resolve.Call(VirtualKeyboardInput.LayerKey, hwnd)
                this.Used := false
                if this.Route == "layer"
                    this.State.AliasDown(VirtualKeyboardInput.LayerKey)
            case "end":
                unused := this.Target && !this.Used
                route := this.Route
                this.ResetInput()
                if unused {
                    if route == "layer" {
                        context := HotkeyContext(VirtualKeyboardInput.LayerKey, modifiers, [], hwnd)
                        this.Dispatcher.PrepareTap(context)
                        this.Tap.Call(context)
                    } else {
                        this.SendKey(route, modifiers)
                    }
                }
            case "key":
                this.Key(request["key"], modifiers, hwnd)
        }
    }

    Key(key, modifiers, hwnd) {
        key := GetKeyName(key)
        if this.Target && this.Route == "layer" {
            context := HotkeyContext(key, modifiers, [VirtualKeyboardInput.LayerKey], hwnd)
            context.Title := WinGetTitle("ahk_id " hwnd)
            context.Process := WinGetProcessName("ahk_id " hwnd)
            context.LogicalModifiers := KeyboardSender.ReadModifiers("")
            binding := this.Registry.Resolve(key, context.Layer, hwnd)
            if binding {
                this.Used := true
                if !this.State.Active
                    return
                try {
                    if binding.Mode == "pass"
                        this.PressModifiers(modifiers)
                    this.Dispatcher.Dispatch(key, context)
                } finally {
                    this.State.KeyUp(key)
                    this.ReleaseModifiers(modifiers)
                }
                return
            }
            if this.State.Blocked.Has(key)
                return
        }
        this.SendKey(key, modifiers, this.Route != "layer" ? this.Route : "")
        if this.Target && this.Route != "layer"
            this.Used := true
    }

    PressModifiers(modifiers) {
        for key, down in modifiers {
            if down && !GetKeyState(key)
                this.Sender.Send("{" key " down}")
        }
    }

    ReleaseModifiers(modifiers) {
        ; 屏幕修饰键仅在发送期间按下，不让之后的鼠标点击变成 Ctrl/Alt 点击。
        keys := ""
        for key, down in modifiers {
            if down && !GetKeyState(key, "P")
                keys .= "{" key " up}"
        }
        if keys != ""
            this.Sender.Send("{vkE8}" keys)
    }

    SendKey(key, modifiers, trigger := "") {
        try {
            this.PressModifiers(modifiers)
            if trigger != ""
                this.Sender.Send("{" trigger " down}")
            this.Sender.Send("{" key "}")
        } finally {
            if trigger != ""
                this.Sender.Send("{" trigger " up}")
            this.ReleaseModifiers(modifiers)
        }
    }

    ResetInput() {
        this.State := LayerState()
        this.Dispatcher.State := this.State
        this.Target := 0
        this.Route := ""
        this.Used := false
    }

    SetEnabled(enabled) {
        this.Enabled := !!enabled
        this.ResetInput()
    }
}
