; 设置修改、持久化与即时应用。
class SettingsActions {
    __New(config) {
        this.Config := config
    }

    Toggle(settings, property, apply := unset, *) {
        this.Set(settings, property, !settings.%property%, IsSet(apply) ? apply : unset)
    }

    Edit(dialog, settings, property, apply := 0, *) {
        dialog.Open(settings.%property%, (value) => this.Set(settings, property, value, apply ? apply : unset))
    }

    Set(settings, property, value, apply := unset, *) {
        previous := settings.%property%
        settings.%property% := value
        try this.Config.SaveAll()
        catch as err {
            settings.%property% := previous
            throw err
        }
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
