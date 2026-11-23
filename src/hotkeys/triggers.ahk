; 将一次物理按键的路由固定到抬起，转发目标按键按引用计数释放。
class TriggerRouter {
    __New(state, sender, resolve) {
        this.State := state
        this.Sender := sender
        this.Resolve := resolve
        this.Held := Map()
        this.Targets := Map()
    }

    AllowsLayer(hwnd) {
        for key in this.State.Held {
            if this.Resolve.Call(key, hwnd) == "layer"
                return true
        }
        return false
    }

    Down(key, hwnd) {
        if this.Held.Has(key)
            return
        route := this.Resolve.Call(key, hwnd)
        this.Held[key] := route
        if route == "layer" {
            this.State.AliasDown(key)
        } else {
            count := this.Targets.Get(route, 0)
            this.Targets[route] := count + 1
            if !count
                this.Sender.Send("{" route " down}")
        }
    }

    Up(key) {
        if !this.Held.Has(key)
            return false
        route := this.Held.Delete(key)
        if route == "layer" {
            return this.State.AliasUp(key)
        } else if route != "" {
            this.Targets[route] -= 1
            if !this.Targets[route] {
                this.Targets.Delete(route)
                this.Sender.Send("{" route " up}")
            }
        }
        return false
    }

    IgnoreUntilUp(key, systemDown) {
        if !this.Held.Has(key) {
            this.Held[key] := ""
            ; 只配平启用前已交给系统的按下。
            if systemDown
                this.Sender.Send("{" key " up}")
        }
    }

    DisableHeld(key) {
        if this.Held.Has(key) {
            this.Up(key)
            ; 已拦截的按下只收尾，不把重复按下或松开单独交给系统。
            this.Held[key] := ""
        }
    }

    Cancel() {
        if this.State.Active {
            this.State.Consume(KeyboardSender.LayerModifiers())
            this.Sender.ReleaseModifiers()
        }
        for target in this.Targets
            this.Sender.Send("{" target " up}")
        this.Targets.Clear()
        for key, route in this.Held {
            if route != "layer"
                this.Held[key] := ""
        }
    }
}
