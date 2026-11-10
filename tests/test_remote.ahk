#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk
#Include ../src/lib/keyboard.ahk
#Include ../src/core/settings.ahk
#Include ../src/rules/ime.ahk
#Include ../src/hotkeys/layers.ahk
#Include ../src/hotkeys/triggers.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/caps_policy.ahk

class RemoteTests {
    static Count := 0
    class FakeSender {
        __New() {
            this.Events := []
            this.Releases := 0
        }
        Send(keys) => this.Events.Push(keys)
        Release(keys) => this.Releases++
    }
    static Matches(name, hwnd) => name == "RemoteDesktop" && hwnd == 7
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }

    static Reset(mode) {
        this.Settings := AppSettings.RemoteDesktop()
        this.Settings.capsMode := mode
        this.Policy := CapsPolicy(this.Settings, ObjBindMethod(this, "Matches"))
        this.State := LayerState()
        this.Sender := this.FakeSender()
        this.Router := TriggerRouter(this.State, this.Sender, ObjBindMethod(this.Policy, "Resolve"))
    }

    static Run() {
        for mode in ["CapsLock", "F1", "F24"] {
            this.Reset(mode)
            this.Assert(this.Policy.Resolve("CapsLock", 8) == "layer", "Ordinary windows retain the local layer")
            this.Assert(this.Policy.Resolve("CapsLock", 7) == mode, "Remote window selects configured route")
            this.Router.Down("CapsLock", 7)
            this.Router.Down("CapsLock", 7)
            this.Assert(this.Sender.Events.Length == 1, "Auto-repeat does not repeat forwarded key-down")
            this.Assert(this.Sender.Events[1] == "{" mode " down}", "Forwarded key-down")
            this.Assert(!this.State.Active && !this.Router.AllowsLayer(7), "Forwarding bypasses local layer")
            this.Settings.capsMode := "layer"
            this.Router.Up("CapsLock")
            this.Assert(this.Sender.Events[2] == "{" mode " up}", "Mode change does not change paired key-up")
            this.Assert(!this.Router.Held.Count && !this.Router.Targets.Count, "Release clears forwarded state")

            this.Reset(mode)
            this.Router.Down("CapsLock", 7)
            this.Router.Down("F6", 7)
            this.Router.Up("CapsLock")
            this.Assert(this.Sender.Events.Length == 1, "Shared destination held until every alias releases")
            this.Router.Up("F6")
            this.Assert(this.Sender.Events.Length == 2, "Shared destination emits one paired key-up")

            this.Reset(mode)
            this.Router.Down("F6", 7)
            this.Router.Cancel()
            this.Router.Down("F6", 8)
            this.Assert(this.Sender.Events.Length == 2 && !this.State.Active, "Pause releases forwarding and blocks held repeat")
            this.Router.Up("F6")
            this.Router.Down("F6", 8)
            this.Assert(this.State.Active, "Repress in ordinary window enters layer")
            this.Router.Up("F6")
        }

        this.Reset("layer")
        this.Router.Down("CapsLock", 7)
        this.Assert(this.State.Active && !this.Sender.Events.Length, "Remote local-layer option")
        this.Router.Cancel()
        this.Assert(this.State.Phase == "Spent" && this.Sender.Releases == 1, "Cancel consumes local layer")
        this.Router.Up("CapsLock")
        this.Assert(this.State.Phase == "Idle", "Local layer key-up after cancellation")

        this.Reset("F1")
        this.Router.Down("F6", 8)
        this.Assert(!this.Router.AllowsLayer(7), "Focus entering remote window blocks local suffix dispatch")
        this.Router.Up("F6")
        this.Assert(!this.Sender.Events.Length && this.State.Phase == "Idle", "Focus change does not invent a forwarded press")
        this.Router.IgnoreUntilUp("F1")
        this.Assert(this.Sender.Events[1] == "{F1 up}", "Enabling held alias releases its existing system-side press")
        this.Router.Down("F1", 8)
        this.Assert(!this.State.Active, "Enabling a physically held alias requires release")
        this.Router.Up("F1")
        this.Router.Down("F1", 8)
        this.Assert(this.State.Active, "Alias rearms after release")
        this.Router.Up("F1")

        this.Settings.capsMode := "layer|CapsLock"
        this.Assert(this.Settings.CheckValid() != "", "Combined mode names are rejected")
        WindowGroups.Register()
        window := Gui(, "Window classifier test")
        window.Show("NA w240 h80")
        try {
            GroupAdd("RemoteDesktop", "ahk_id " window.Hwnd)
            policy := CapsPolicy(AppSettings.RemoteDesktop())
            this.Assert(policy.Resolve("CapsLock", window.Hwnd) == "F1", "Real window group is used by default matcher")
            this.Assert(policy.Resolve("CapsLock", 0) == "layer", "Missing foreground window has no remote match")
        } finally window.Destroy()
        FileAppend("PASS: " this.Count " remote routing assertions" Chr(10), "*", "UTF-8")
    }
}

try {
    RemoteTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}
