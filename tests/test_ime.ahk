#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/ime.ahk
#Include ../src/rules/ime.ahk
#Include ../src/core/settings.ahk
#Include ../src/actions/ime.ahk
#Include ../src/hotkeys/layers.ahk
#Include ../src/hotkeys/registry.ahk
#Include ../src/hotkeys/dispatcher.ahk
#Include ../src/hotkeys/triggers.ahk
#Include ../src/hotkeys/native.ahk
#Include ../src/hotkeys/keyboard_hook.ahk

class ImeTests {
    static Count := 0
    static Opened := false
    static TapCount := 0
    class FakeSender {
        __New() => this.Events := []
        Send(keys) => this.Events.Push(keys)
        Release(keys) => this.Events.Push("release:" keys.Length)
    }
    class FakeApi {
        CurrentLanguage := ImeApi.Chinese
        Toggles := 0
        Success := true
        Language(hwnd) => this.CurrentLanguage
        ToggleOpen(hwnd) {
            this.Toggles++
            return this.Success
        }
    }
    class LocalIme extends ImeApi {
        Window(hwnd) => hwnd
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static NoAction(context) {
    }
    static Route(key, hwnd) => hwnd == 2 ? "F1" : "layer"
    static ImeMessage(command, value, *) {
        switch command {
            case ImeApi.GetOpenStatus:
                return this.Opened
            case ImeApi.SetOpenStatus:
                this.Opened := !!value
                return 0
        }
    }

    static Run() {
        sender := this.FakeSender(), api := this.FakeApi(), settings := AppSettings.IME()
        actions := ImeActions(settings, api, sender)
        context := HotkeyContext("F6", Map(), ["F6"], 1)
        for mode, expected in Map("ctrl_space", "^{Space}", "weasel", "^{F20}", "shift", "{Shift}") {
            settings.chineseToggle := mode
            actions.ToggleLanguage(context)
            this.Assert(sender.Events[-1] == expected, "Chinese toggle method: " mode)
        }
        settings.chineseToggle := ImeMethods.Api
        before := sender.Events.Length
        this.Assert(actions.ToggleLanguage(context) && api.Toggles == 1, "Chinese API mode calls IMM")
        this.Assert(sender.Events.Length == before, "API mode sends no fallback shortcut")
        for mode, expected in Map("ctrl_period", "^{.}", "weasel", "^{F21}") {
            settings.chinesePunctuation := mode
            actions.PrimaryMode(context)
            this.Assert(sender.Events[-1] == expected, "Chinese punctuation method: " mode)
        }
        api.CurrentLanguage := ImeApi.Korean
        actions.ToggleLanguage(context)
        this.Assert(sender.Events[-1] == "{vk15}", "Korean uses Hangul key, independent of Chinese mode")
        actions.PrimaryMode(context)
        this.Assert(sender.Events[-1] == "{vk19}", "Korean uses Hanja key")
        api.CurrentLanguage := ImeApi.Japanese
        actions.ToggleLanguage(context)
        this.Assert(sender.Events[-1] == "!{vkC0sc029}", "Japanese uses Alt+grave")
        before := sender.Events.Length
        this.Assert(actions.PrimaryMode(context) && sender.Events[-1] == "^{CapsLock}", "Japanese primary action selects Hiragana")
        this.Assert(actions.SecondaryMode(context) && sender.Events[-1] == "!{CapsLock}", "Japanese secondary action selects Katakana")
        before := sender.Events.Length
        api.CurrentLanguage := 0
        this.Assert(!actions.SecondaryMode(context) && sender.Events.Length == before, "Non-Japanese secondary action emits nothing")
        this.Assert(!actions.ToggleLanguage(context) && sender.Events.Length == before, "Unsupported language emits no input")
        this.Assert(settings.CheckValid() == "", "Supported settings validate")
        for property, language in Map("koreanToggle", ImeApi.Korean, "japaneseToggle", ImeApi.Japanese) {
            api.CurrentLanguage := language
            settings.%property% := ImeMethods.Api
            before := sender.Events.Length
            toggles := api.Toggles
            this.Assert(actions.ToggleLanguage(context) && api.Toggles == toggles + 1, property " calls IMM")
            this.Assert(sender.Events.Length == before, property " API sends no shortcut")
            api.Success := false
            this.Assert(!actions.ToggleLanguage(context) && sender.Events.Length == before, property " preserves API failure without fallback")
            api.Success := true
            this.Assert(settings.CheckValid() == "", property " accepts API setting")
            settings.%property% := "unknown"
            this.Assert(settings.CheckValid() != "", property " rejects unknown method")
            settings.%property% := ImeMethods.Api
        }
        settings.chineseToggle := "unknown"
        this.Assert(settings.CheckValid() != "", "Unknown toggle method rejected")
        settings.chineseToggle := ImeMethods.CtrlSpace
        settings.chinesePunctuation := "unknown"
        this.Assert(settings.CheckValid() != "", "Unknown punctuation method rejected")
        this.Sessions()
        this.InputAdapter()
        this.NativeApi()
        FileAppend("PASS: " this.Count " IME and unused-layer assertions" Chr(10), "*", "UTF-8")
    }

    static Sessions() {
        state := LayerState(), sender := this.FakeSender()
        registry := HotkeyRegistry()
        registry.Pass("1", ObjBindMethod(this, "NoAction"))
        registry.Layers("2", Map(1, ObjBindMethod(this, "NoAction")))
        dispatcher := HotkeyDispatcher(state, registry, sender)
        router := TriggerRouter(state, sender, ObjBindMethod(this, "Route"))

        router.Down("F6", 1)
        this.Assert(router.Up("F6"), "Unused layer requests one tap on release")
        this.Assert(!router.Up("F6"), "Duplicate release never requests a tap")
        router.Down("F6", 1)
        router.Down("F1", 1)
        this.Assert(!router.Up("F6"), "First alias release does not toggle")
        this.Assert(router.Up("F1"), "Last alias release requests one toggle")

        router.Down("F6", 1)
        dispatcher.Dispatch("1", HotkeyContext("1", Map(), ["F6"], 1))
        state.KeyUp("1")
        this.Assert(state.Active && state.Used && !router.Up("F6"), "Passthrough action suppresses tap without ending the layer")
        router.Down("F6", 1)
        dispatcher.Dispatch("2", HotkeyContext("2", Map(), ["F6"], 1))
        this.Assert(!router.Up("F6"), "Consumed layer does not toggle")
        state.KeyUp("2")
        router.Down("F6", 1)
        router.Cancel()
        this.Assert(!router.Up("F6"), "Pause or exit cancellation does not toggle")
        router.Down("F6", 2)
        this.Assert(!router.Up("F6"), "Remote forwarded alias does not toggle")
        router.IgnoreUntilUp("F1")
        this.Assert(!router.Up("F1"), "Ignored held alias does not toggle")

        router.Down("F6", 1)
        this.Assert(!dispatcher.Dispatch("9", HotkeyContext("9", Map(), ["F6"], 1)), "Unregistered key does not execute a hotkey")
        this.Assert(router.Up("F6"), "Session with no executed hotkey remains unused")
        context := HotkeyContext("F6", Map("LShift", true, "RAlt", true), ["F6"], 1)
        dispatcher.PrepareTap(context)
        this.Assert(context.Mode == "tap" && sender.Events[-1] == "release:1", "Tap prepares input release before its action")
        this.Assert(state.Captured.Has("LShift") && state.Captured.Has("RAlt"), "Tap captures modifier key-up cleanup")
        this.Assert(state.Phase == "Idle", "Tap does not open a new layer")
    }

    static NativeApi() {
        api := ImeApi()
        this.Assert(!api.Language(0) && !api.Window(0) && !api.ToggleOpen(0), "Missing foreground has no IME target")
        window := Gui(, "IME API test")
        window.AddEdit("w120", "")
        window.Show("NA w180 h80")
        callback := ObjBindMethod(this, "ImeMessage")
        OnMessage(ImeApi.WmImeControl, callback)
        try {
            this.Assert(api.Language(window.Hwnd) > 0, "Foreground-thread keyboard layout API returns a language")
            testApi := this.LocalIme()
            this.Assert(testApi.ToggleOpen(window.Hwnd) && this.Opened, "Real WM_IME_CONTROL transport opens isolated test IME")
            this.Assert(testApi.ToggleOpen(window.Hwnd) && !this.Opened, "Real WM_IME_CONTROL transport closes isolated test IME")
            this.Opened := true
            this.Assert(testApi.WithClosed(window.Hwnd, () => !this.Opened), "Typing callback runs with IME closed")
            this.Assert(this.Opened, "Typing restores open IME")
            failed := false
            try testApi.WithClosed(window.Hwnd, ObjBindMethod(this, "FailTyping"))
            catch Error
                failed := true
            this.Assert(failed && this.Opened, "Typing failure restores IME and propagates error")
            this.Opened := false
            testApi.WithClosed(window.Hwnd, () => this.Assert(!this.Opened, "Closed IME stays closed during typing"))
            this.Assert(!this.Opened, "Closed IME stays closed after typing")
        } finally {
            OnMessage(ImeApi.WmImeControl, callback, 0)
            window.Destroy()
        }
    }

    static OnTap(state, sender, context) {
        this.Assert(state.Phase == "Idle" && sender.Events[-1] == "release:1", "Input adapter releases before invoking tap action")
        this.Assert(context.Mode == "tap" && context.Hwnd == 1, "Input adapter delivers captured tap context")
        this.Assert(!A_IsCritical, "Tap action runs outside input critical section")
        this.TapCount++
    }

    static FailTyping() {
        this.Assert(!this.Opened, "Failing callback also runs with IME closed")
        throw Error("Typing failure")
    }

    static InputAdapter() {
        state := LayerState(), sender := this.FakeSender(), registry := HotkeyRegistry()
        dispatcher := HotkeyDispatcher(state, registry, sender)
        router := TriggerRouter(state, sender, ObjBindMethod(this, "Route"))
        input := HotkeyInput(state, registry, dispatcher, router, Map("F6", true), ObjBindMethod(this, "OnTap", state, sender))
        router.Down("F6", 1)
        input.EndAlias("F6", 1, Map("LShift", true))
        this.Assert(this.TapCount == 1 && state.Captured.Has("LShift"), "Input adapter invokes one tap and captures modifier release")
        state.KeyUp("LShift")
        input.EndAlias("F6", 1, Map())
        this.Assert(this.TapCount == 1, "Repeated input key-up does not repeat action")
        router.Down("F6", 1)
        input.EndAlias("F6", 2, Map())
        this.Assert(this.TapCount == 1, "Focus entering remote forwarding window suppresses local tap")
        router.Down("F6", 2)
        input.EndAlias("F6", 1, Map())
        this.Assert(this.TapCount == 1, "Forwarded key released in local window does not become tap")
        router.Down("F6", 1)
        input.SetEnabled(false)
        input.EndAlias("F6", 1, Map())
        this.Assert(this.TapCount == 1 && !state.Held.Count, "Paused input still completes release without IME action")
        input.SetEnabled(true)
        router.Down("F6", 1)
        state.Captured["2"] := true
        input.ResetInput()
        input.EndAlias("F6", 1, Map())
        this.Assert(this.TapCount == 1 && state.Phase == "Idle" && !router.Held.Count && !state.Captured.Count, "Reset clears stale input without invoking IME tap")
        router.Down("F6", 2)
        input.ResetInput()
        this.Assert(!router.Targets.Count && !router.Held.Count && sender.Events[-1] == "{F1 up}", "Reset releases forwarded remote target")
    }
}

try {
    ImeTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}
