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
