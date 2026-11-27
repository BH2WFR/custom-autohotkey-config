; 先选择动作，再消费会话和释放按键；回调统一接收触发时的快照。
class HotkeyDispatcher {
    __New(state, registry, sender) {
        this.State := state
        this.Registry := registry
        this.Sender := sender
    }

    Dispatch(key, context) {
        watch := false
        try return this._Dispatch(key, context, &watch)
        finally {
            if watch
                watch.Stop()
        }
    }

    _Dispatch(key, context, &watch) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.State.Active || this.State.Captured.Has(key)
                return false
            binding := this.Registry.Resolve(key, context.Layer, context.Hwnd)
            if !binding
                return false
            this.State.Capture(key)
            context.Mode := binding.Mode
            if binding.Mode == "once"
                this.State.Consume(context.Modifiers, key)
            if binding.Mode != "pass" {
                if binding.Mode == "layers"
                    watch := KeyboardSender.WatchInjectedReleases(context.LogicalModifiers)
                this.Sender.ReleaseModifiers()
            }
        } finally {
            Critical(previousCritical)
        }
        try binding.Callback.Call(context)
        finally {
            if binding.Mode == "layers" && context.RestoreModifiers && this.State.Phase != "Spent"
                this.Sender.RestoreModifiers(context.LogicalModifiers, watch)
        }
        return true
    }

    ; 由输入适配器在 AliasUp 的临界区内准备，回调在临界区外执行。
    PrepareTap(context) {
        context.Mode := "tap"
        this.State.Consume(context.Modifiers)
        this.Sender.ReleaseModifiers()
    }
}

class HotkeyContext {
    WheelSteps := 1
    __New(key, modifiers, triggers, hwnd := 0) {
        this.Key := key
        this.Modifiers := modifiers
        this.Layer := LayerState.LayerOf(modifiers)
        this.Triggers := triggers
        this.Hwnd := hwnd
        this.Mode := ""
        this.Title := ""
        this.Process := ""
        this.LogicalModifiers := Map()
        this.RestoreModifiers := true
    }
}
