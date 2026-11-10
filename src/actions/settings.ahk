; 设置修改、持久化与即时应用。
class SettingsActions {
    __New(config) {
        this.Config := config
    }

    Toggle(settings, property, apply := unset, *) {
        this.Set(settings, property, !settings.%property%, IsSet(apply) ? apply : unset)
    }

    Set(settings, property, value, apply := unset, *) {
        settings.%property% := value
        this.Config.SaveAll()
        if IsSet(apply)
            apply.Call(value)
    }

    Reload(apply, *) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.Config.LoadAll()
            apply.Call()
        } finally Critical(previousCritical)
    }

    static Read(settings, property, *) => settings.%property%
    static Equals(settings, property, value, *) => settings.%property% == value
}
