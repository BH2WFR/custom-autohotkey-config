; Caps 层会话与物理按键收尾；不依赖定时轮询。
class LayerState {
    __New() {
        this.Phase := "Idle"
        this.Held := Map()
        this.Captured := Map()
        this.Blocked := Map()
        this.Used := false
    }

    Active => this.Phase == "Active"

    AliasDown(key) {
        if this.Held.Has(key)
            return
        this.Held[key] := true
        if this.Phase == "Idle" {
            this.Phase := "Active"
            this.Used := false
        }
    }

    AliasUp(key) {
        if !this.Held.Has(key)
            return false
        this.Held.Delete(key)
        unused := !this.Held.Count && this.Active && !this.Used
        if !this.Held.Count {
            this.Phase := "Idle"
            this.Blocked.Clear()
        }
        return unused
    }

    Capture(key) {
        if this.Captured.Has(key)
            return false
        this.Captured[key] := true
        this.Used := true
        return true
    }

    KeyUp(key) {
        if this.Captured.Has(key)
            this.Captured.Delete(key)
    }

    Consume(modifiers, key := "") {
        this.Used := true
        this.Phase := this.Held.Count ? "Spent" : "Idle"
        if key != "" && this.Held.Count
            this.Blocked[key] := true
        for key, down in modifiers {
            if down
                this.Captured[key] := true
        }
    }

    Triggers() {
        result := []
        for key in this.Held
            result.Push(key)
        return result
    }

    static LayerOf(modifiers) {
        shift := modifiers.Get("LShift", false) || modifiers.Get("RShift", false)
        alt := modifiers.Get("LAlt", false) || modifiers.Get("RAlt", false)
        return 1 + shift + 2 * alt
    }
}
