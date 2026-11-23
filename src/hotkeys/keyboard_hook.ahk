; 使用 AHK 原生 hook 热键，只监听别名、已注册功能键和待收尾的修饰键。
class HotkeyInput {
    static ExitMenuLoopMessage := 0x0212
    static DeferredCleanup := -1
    __New(state, registry, dispatcher, triggers, aliases, tap) {
        this.State := state
        this.Registry := registry
        this.Dispatcher := dispatcher
        this.Triggers := triggers
        this.Aliases := aliases
        this.Tap := tap
        this.Native := NativeHotkeys()
        this.Started := false
        this.Enabled := true
        this.MenuExitCallback := ObjBindMethod(this, "MenuExited")
        this.ReconcileCallback := ObjBindMethod(this, "ReconcileReleased")
    }

    Start() {
        InstallKeybdHook()
        OnMessage(HotkeyInput.ExitMenuLoopMessage, this.MenuExitCallback)
        for key, enabled in this.Aliases {
            if enabled && GetKeyState(key)
                this.Triggers.IgnoreUntilUp(key, true)
            ; Layer 原键由无条件钩子成对拦截，开关变更时才更新注册状态。
            this.Native.Add("*" key, ObjBindMethod(this, "AliasDown", key), "", enabled)
            this.Native.Add("*" key " up", ObjBindMethod(this, "AliasUp", key), "", enabled)
        }
        this.Started := true
        for key in this.Registry.Bindings {
            pulse := NativeHotkeys.IsPulse(key)
            this._Register("*" key, ObjBindMethod(this, pulse ? "KeyPulse" : "KeyDown", key), ObjBindMethod(this, "CanHandle", key))
            if !pulse
                this._Register("*" key " up", ObjBindMethod(this, "KeyUp", key), ObjBindMethod(this, "IsCaptured", key))
        }
        for key in KeyboardSender.ModifierKeys {
            condition := ObjBindMethod(this, "IsCaptured", key)
            this._Register("*" key, ObjBindMethod(this, "Ignore"), condition)
            this._Register("*" key " up", ObjBindMethod(this, "KeyUp", key), condition)
        }
    }

    _Register(name, callback, condition) {
        this.Native.Add(name, callback, condition)
    }

    Stop() {
        this.Started := false
        OnMessage(HotkeyInput.ExitMenuLoopMessage, this.MenuExitCallback, 0)
        SetTimer(this.ReconcileCallback, 0)
        this.Triggers.Cancel()
        this.Native.Stop()
    }

    ResetInput() {
        this.Triggers.Cancel()
        this.ReconcileReleased()
    }

    MenuExited(*) {
        ; 原生菜单循环退出后再收尾，同样覆盖托盘菜单。
        SetTimer(this.ReconcileCallback, HotkeyInput.DeferredCleanup)
    }

    ; 原生菜单结束或重置钩子时补齐遗漏的 KeyUp，不触发轻按动作。
    ReconcileReleased() {
        ; 已松开的残留记录直接收尾，仍按住的键必须先松开。
        for key in this.Triggers.Held.Clone() {
            if !GetKeyState(key, "P") {
                this.Triggers.Up(key)
                if !this.AliasEnabled(key)
                    this.SyncAlias(key)
            }
        }
        for key in this.State.Captured.Clone() {
            if !GetKeyState(key, "P")
                this.State.KeyUp(key)
        }
    }

    SetAliasEnabled(key, enabled) {
        if this.Aliases[key] == !!enabled
            return
        ; 开启时已被按住的键要先松开，不能由重复 KeyDown 新开一轮。
        if enabled && this.Enabled && GetKeyState(key, "P") {
            this.Triggers.IgnoreUntilUp(key, GetKeyState(key))
        } else if !enabled {
            this.Triggers.DisableHeld(key)
        }
        this.Aliases[key] := !!enabled
        this.SyncAlias(key)
    }

    SetEnabled(enabled) {
        this.Enabled := !!enabled
        if !enabled {
            this.Triggers.Cancel()
        } else {
            for key, active in this.Aliases {
                if active && GetKeyState(key, "P") {
                    this.Triggers.IgnoreUntilUp(key, GetKeyState(key))
                }
            }
        }
        for key in this.Aliases
            this.SyncAlias(key)
    }

    SyncAlias(key) {
        if !this.Started
            return
        state := this.AliasEnabled(key) ? "On" : "Off"
        HotIf()
        Hotkey("*" key, state)
        Hotkey("*" key " up", state)
    }

    AliasEnabled(key, *) => (this.Enabled && this.Aliases[key]) || this.Triggers.Held.Has(key)
    IsCaptured(key, *) => this.State.Captured.Has(key)

    CanHandle(key, *) {
        if this.State.Captured.Has(key)
            return true
        if this.State.Blocked.Has(key)
            return true
        if !this.Enabled || !this.State.Held.Count
            return false
        layer := LayerState.LayerOf(KeyboardSender.ReadModifiers())
        hwnd := WinExist("A")
        if !this.Triggers.AllowsLayer(hwnd)
            return false
        return !!this.Registry.Resolve(key, layer, hwnd)
    }

    AliasDown(key, *) {
        previousCritical := A_IsCritical
        Critical("On")
        try this.Triggers.Down(key, WinExist("A"))
        finally Critical(previousCritical)
    }

    AliasUp(key, *) => this.EndAlias(key, WinExist("A"), KeyboardSender.ReadModifiers())

    EndAlias(key, hwnd, modifiers) {
        previousCritical := A_IsCritical
        Critical("On")
        context := false
        try {
            triggers := this.State.Triggers()
            allowed := this.Triggers.AllowsLayer(hwnd)
            unused := this.Triggers.Up(key)
            if !this.AliasEnabled(key)
                this.SyncAlias(key)
            if unused && this.Enabled && hwnd && allowed {
                context := HotkeyContext(key, modifiers, triggers, hwnd)
                this.Dispatcher.PrepareTap(context)
            }
        }
        finally Critical(previousCritical)
        if context
            this.Tap.Call(context)
    }

    KeyDown(key, *) {
        ; Dispatcher 只保护短状态转换；动作回调保持可中断。
        if this.State.Captured.Has(key)
            return
        ; 一次性动作结束层后仍吸收匹配键，直到最后一个别名物理松开。
        if !this.State.Active {
            if this.State.Held.Count
                this.State.Capture(key)
            return
        }
        modifiers := KeyboardSender.ReadModifiers()
        hwnd := WinExist("A")
        if !this.Triggers.AllowsLayer(hwnd)
            return
        context := HotkeyContext(key, modifiers, this.State.Triggers(), hwnd)
        context.LogicalModifiers := KeyboardSender.ReadModifiers("")
        if hwnd {
            try {
                context.Title := WinGetTitle("ahk_id " hwnd)
                context.Process := WinGetProcessName("ahk_id " hwnd)
            } catch TargetError {
                return
            }
        }
        this.Dispatcher.Dispatch(key, context)
    }

    KeyUp(key, *) => this.State.KeyUp(key)
    KeyPulse(key, *) {
        try this.KeyDown(key)
        finally this.KeyUp(key)
    }
    Ignore(*) {
    }
}
