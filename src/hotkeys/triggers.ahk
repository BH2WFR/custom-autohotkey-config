; 将一次物理按键的路由固定到抬起，转发目标按键按引用计数释放。
class TriggerRouter {
    __New(state, sender, resolve) {
        this.State := state
        this.Sender := sender
        this.Resolve := resolve
        this.Held := Map()
        this.Targets := Map()
    }

    AllowsLayer(hwnd) => this.Resolve.Call("", hwnd) == "layer"

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

    IgnoreUntilUp(key) {
        if !this.Held.Has(key) {
            this.Held[key] := ""
            this.Sender.Send("{" key " up}")
        }
    }

    Cancel() {
        if this.State.Active {
            this.State.Consume(KeyboardSender.ReadModifiers())
            this.Sender.Release(this.State.Triggers())
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
