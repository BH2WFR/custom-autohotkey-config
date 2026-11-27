; 原生热键注册与卸载，不包含项目按键表。
class NativeHotkeys {
    static PulseKeys := Map("WheelUp", true, "WheelDown", true, "WheelLeft", true, "WheelRight", true)
    static IsPulse(key) => this.PulseKeys.Has(key)

    static ResetHooks() {
        InstallKeybdHook(true, true)
        InstallMouseHook(true, true)
    }

    __New() {
        this.Entries := []
    }

    Add(name, callback, condition := "", enabled := true) {
        HotIf(condition)
        try Hotkey(name, callback, enabled ? "I0 On" : "I0 Off")
        finally HotIf()
        this.Entries.Push({Name: name, Condition: condition})
    }

    Stop() {
        for entry in this.Entries {
            HotIf(entry.Condition)
            try Hotkey(entry.Name, "Off")
            finally HotIf()
        }
    }
}

; A_EventInfo 是无符号滚动量，方向来自热键名。斜向滚动时两个轴分别累计。
class WheelAccumulator {
    static DeltaPerNotch := 120
    Enabled := false
    Axes := Map()

    Reset() => this.Axes.Clear()

    SetEnabled(enabled) {
        if this.Enabled != !!enabled {
            this.Reset()
            this.Enabled := !!enabled
        }
    }

    Take(key, amount, route, hwnd := unset) {
        if !this.Enabled
            return 1
        ; 整格立即生效，仅零头参与累计，避免触控板余量抵消普通鼠标的反向一格。
        notches := amount // WheelAccumulator.DeltaPerNotch
        fraction := Mod(amount, WheelAccumulator.DeltaPerNotch)
        vertical := key == "WheelUp" || key == "WheelDown"
        axis := this.Axes.Get(vertical, false)
        if !fraction && !axis
            return notches
        if !IsSet(hwnd)
            hwnd := WinExist("A")
        if !axis || axis.Route != route || axis.Hwnd != hwnd
            this.Axes[vertical] := axis := {Route: route, Hwnd: hwnd, Remainder: 0}
        delta := key == "WheelUp" || key == "WheelRight" ? fraction : -fraction
        total := axis.Remainder + delta
        axis.Remainder := Mod(total, WheelAccumulator.DeltaPerNotch)
        if !axis.Remainder
            this.Axes.Delete(vertical)
        return notches + Abs(total) // WheelAccumulator.DeltaPerNotch
    }

    Dispatch(key, route, action, *) {
        previousCritical := Critical("On")
        try {
            count := this.Take(key, A_EventInfo, route)
            if count
                action.Call(count)
        } finally Critical(previousCritical)
    }
}
