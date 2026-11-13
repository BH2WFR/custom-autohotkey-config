#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk
#Include ../src/lib/python.ahk
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/typing.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/lib/text.ahk
#Include ../src/lib/editing.ahk
#Include ../src/lib/window.ahk
#Include ../src/lib/window_info.ahk
#Include ../src/lib/process.ahk
#Include ../src/lib/shell.ahk
#Include ../src/lib/ime.ahk
#Include ../src/lib/mouse.ahk
#Include ../src/lib/touchpad.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/lib/window_automation.ahk
#Include ../src/utils/tooltip.ahk
#Include ../src/utils/console.ahk
#Include ../src/utils/filesystem.ahk
#Include ../src/core/settings.ahk
#Include ../src/rules/ime.ahk
#Include ../src/core/autorun.ahk
#Include ../src/core/session.ahk
#Include ../src/hotkeys/native.ahk
#Include ../src/hotkeys/layers.ahk
#Include ../src/hotkeys/registry.ahk
#Include ../src/hotkeys/dispatcher.ahk
#Include ../src/hotkeys/triggers.ahk
#Include ../src/hotkeys/keyboard_hook.ahk
#Include ../src/hotkeys/virtual_keyboard.ahk
#Include ../src/actions/diagnosis.ahk
#Include ../src/actions/screen_keyboard.ahk
#Include ../src/actions/personal_scripts.ahk
#Include ../src/actions/unicode_inspector.ahk
#Include ../src/actions/settings.ahk
#Include ../src/actions/application.ahk
#Include ../src/actions/mouse.ahk
#Include ../src/actions/pointer.ahk
#Include ../src/actions/wheel.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/actions/middle_drag.ahk
#Include ../src/actions/xbuttons.ahk
#Include ../src/actions/window.ahk
#Include ../src/actions/window_inspector.ahk
#Include ../src/actions/keyboard.ahk
#Include ../src/actions/paths.ahk
#Include ../src/actions/clipboard.ahk
#Include ../src/actions/text.ahk
#Include ../src/actions/ime.ahk
#Include ../src/actions/joystick.ahk
#Include ../src/apps/anki.ahk
#Include ../src/apps/xbuttons.ahk
#Include ../src/apps/caj_viewer.ahk
#Include ../src/apps/power_iso.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/editing.ahk
#Include ../src/rules/caps_policy.ahk
#Include ../src/rules/hotkeys.ahk
#Include ../src/rules/paths.ahk
#Include ../src/rules/mouse.ahk
#Include ../src/rules/wheel.ahk
#Include ../src/rules/middle_drag.ahk
#Include ../src/rules/tray.ahk
#Include ../src/ui/tray.ahk
#Include ../src/ui/popup_menu.ahk
#Include ../src/ui/window_picker.ahk
#Include ../src/ui/window_inspector.ahk
#Include ../src/ui/dpi_gui.ahk
#Include ../src/core/app.ahk

class AppTests {
    static Count := 0
    static Directory := A_ScriptDir "\..\tmp\app-test-" A_TickCount

    class FakeActions {
        __New() {
            this.Events := []
        }
        Middle(down) => this.Events.Push(down ? "down" : "up")
        Scroll(direction) => this.Events.Push(direction)
    }

    class FakeKeys {
        Send(keys) => this.Last := keys
    }

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }

    static Run() {
        App.Start(this.Directory, A_ScriptDir "\..")
        OnExit(ObjBindMethod(this, "Cleanup"))
        if A_Args.Length && A_Args[1] == "--keyboard-only" {
            this.ScreenKeyboard()
            App.Session.SetPaused(true)
            this.Assert(!App.VirtualKeyboard.Enabled, "Pause disables screen keyboard input")
            App.Session.SetPaused(false)
            this.Assert(App.VirtualKeyboard.Enabled, "Resume enables screen keyboard input")
            App.Stop()
            FileAppend("PASS: " this.Count " screen keyboard app assertions`n", "*", "UTF-8")
            return
        }
        this.Assert(InStr(A_IconFile, "MainIcon.ico"), "Normal icon loaded")
        this.Assert(A_TrayMenu.Default == "&Open", "Default tray action opens native AHK window")
        for id in ["f1", "mouse", "config", "readConfig"]
            this.Assert(App.Tray.Entries[id].Menu == A_TrayMenu, "Frequent toggle stays at root: " id)
        for id in ["xbuttons", "reverse", "transparency", "autorun", "ime/chineseToggle/api", "remote/F1"]
            this.Assert(App.Tray.Entries[id].Menu != A_TrayMenu, "Settings are in submenus: " id)
        this.Assert(this.MenuHas(A_TrayMenu, "&Open") && this.MenuHas(A_TrayMenu, "&Window Spy")
            && this.MenuHas(A_TrayMenu, "&Reload Script") && this.MenuHas(A_TrayMenu, "E&xit"), "Native AHK tools and lifecycle entries retained")
        this.Assert(!App.Mouse.FunctionKeys, "F2/F3/F4 disabled at startup")
        invalidWheelUp := false
        for entry in App.Input.Native.Entries
            invalidWheelUp := invalidWheelUp || RegExMatch(entry.Name, "i)Wheel.* up$")
        this.Assert(!invalidWheelUp, "Wheel registration has no key-up hotkey")
        this.Assert(App.XButtons.IsEnabled() && App.MouseSettings.xButtonMapping, "Side-button mapping enabled by default")
        this.Assert(Config.LoadJson(App.Config.Path)["IME"]["chineseToggle"] == ImeMethods.CtrlSpace, "Default Chinese IME method persisted")
        this.Assert(FileExist(App.Python.Executable), "Configured Conda interpreter resolved")
        this.Assert(AppSettings.GetDirectory() == EnvGet("USERPROFILE") "\.config\custom-autohotkey-config", "Project owns configuration path")
        this.Assert(PythonRuntime.Resolve("__missing_test_environment__") == "", "Unknown environment does not use base")

        App.Tray.Invoke("f1")
        data := Config.LoadJson(App.Config.Path)
        this.Assert(data["Keyboard"]["f1Alias"] == 0 && !App.Input.Aliases["F1"], "F1 persisted and applied")
        App.Tray.Invoke("f1")
        App.Tray.Invoke("reverse")
        App.Tray.Invoke("transparency")
        data := Config.LoadJson(App.Config.Path)
        this.Assert(data["Mouse"]["reverseHorizontal"] == 1, "Horizontal option persisted")
        this.Assert(data["Mouse"]["winWheelTransparency"] == 0, "Transparency option persisted")
        App.Tray.Invoke("mouse")
        this.Assert(App.Mouse.FunctionKeys, "Function key toggle applied")
        this.Assert(!data["Mouse"].Has("FunctionKeys"), "Function key mode not persisted")
        App.Tray.Invoke("remote/F24")
        this.Assert(Config.LoadJson(App.Config.Path)["RemoteDesktop"]["capsMode"] == "F24", "Remote mode persisted")
        this.Assert(App.RemoteSettings.capsMode == "F24", "Remote mode applied to policy settings")
        App.Tray.Invoke("ime/chineseToggle/weasel")
        this.Assert(App.Ime.Settings.chineseToggle == ImeMethods.Weasel, "Chinese IME method applied immediately")
        this.Assert(Config.LoadJson(App.Config.Path)["IME"]["chineseToggle"] == ImeMethods.Weasel, "Chinese IME method persisted")
        App.Tray.Invoke("ime/chinesePunctuation/weasel")
        this.Assert(App.Ime.Settings.chinesePunctuation == ImeMethods.Weasel, "Chinese punctuation method applied")
        for property in ["koreanToggle", "japaneseToggle"] {
            App.Tray.Invoke("ime/" property "/api")
            this.Assert(App.Ime.Settings.%property% == ImeMethods.Api, property " applied immediately")
            this.Assert(Config.LoadJson(App.Config.Path)["IME"][property] == ImeMethods.Api, property " persisted")
        }

        App.Tray.Invoke("xbuttons")
        this.Assert(!App.XButtons.IsEnabled() && Config.LoadJson(App.Config.Path)["Mouse"]["xButtonMapping"] == 0, "Side-button switch applied and persisted")
        App.Tray.Invoke("pause")
        this.Assert(App.Session.Paused && !App.Input.Enabled && !App.Mouse.Enabled && !App.XButtons.Enabled && !App.MiddleDrag.Enabled, "Pause disables all adapters")
        this.Assert(!App.Input.AliasEnabled("F6"), "Paused Caps alias passes through")
        this.Assert(InStr(A_IconFile, "MainSuspend.ico"), "Paused icon loaded")
        this.Assert(!App.Touchpad.Enabled, "Pause disables touch injection")
        App.Tray.Invoke("resetHooks")
        this.Assert(App.Session.Paused && !App.Input.Enabled && !App.Mouse.Enabled && !App.XButtons.Enabled && !App.MiddleDrag.Enabled, "Hook reset preserves paused controllers")
        this.Assert(InStr(A_IconFile, "MainSuspend.ico"), "Hook reset preserves paused icon")
        App.Tray.Invoke("pause")
        this.Assert(!App.Session.Paused && App.Input.Enabled && App.Mouse.Enabled, "Resume enables both adapters")
        this.Assert(!App.XButtons.IsEnabled(), "Resume preserves disabled side-button mapping")
        App.Tray.Invoke("pause")
        App.Tray.Invoke("xbuttons")
        this.Assert(App.MouseSettings.xButtonMapping && !App.XButtons.IsEnabled(), "Enabling mapping does not bypass pause")
        App.Tray.Invoke("pause")
        this.Assert(App.XButtons.IsEnabled(), "Resume applies enabled mapping preference")
        this.Assert(InStr(A_IconFile, "MainIcon.ico"), "Resume restores icon")
        this.Assert(App.Touchpad.Enabled, "Resume enables touch injection")
        this.CapsBindings()
        entries := App.Input.Native.Entries.Length + App.MouseNative.Entries.Length
        App.XButtons.Held["XButton1"] := true
        App.Mouse.Held["F3"] := "scroll"
        App.MiddleDrag.Held := true
        App.Tray.Invoke("resetHooks")
        App.Tray.Invoke("resetHooks")
        this.Assert(!App.Session.Paused && App.Input.Enabled && App.MiddleDrag.Enabled, "Hook reset preserves running state")
        this.Assert(App.Mouse.FunctionKeys && App.Input.Aliases["F1"] && App.XButtons.IsEnabled(), "Hook reset preserves user toggles")
        this.Assert(!App.XButtons.Held.Count && !App.Mouse.Held.Count && !App.MiddleDrag.Held, "Hook reset clears stale mouse records")
        this.Assert(entries == App.Input.Native.Entries.Length + App.MouseNative.Entries.Length, "Repeated hook reset does not duplicate registrations")

        this.MouseCleanup()
        this.AutorunShortcut()
        this.ScreenKeyboard()
        this.PythonArguments()
        this.Transparency()
        this.ReloadSettings()
        App.Tray.Invoke("mouse")
        App.MouseSettings.reverseHorizontal := !App.MouseSettings.reverseHorizontal
        App.Stop()
        this.Assert(Config.LoadJson(App.Config.Path)["Mouse"]["reverseHorizontal"] == App.MouseSettings.reverseHorizontal, "Shutdown saves current settings")
        FileAppend("PASS: " this.Count " app assertions" Chr(10), "*", "UTF-8")
    }

    static MenuHas(menu, label) {
        loop DllCall("GetMenuItemCount", "Ptr", menu.Handle) {
            text := Buffer(512)
            DllCall("GetMenuStringW", "Ptr", menu.Handle, "UInt", A_Index - 1,
                "Ptr", text, "Int", text.Size // 2, "UInt", 0x400)
            if StrGet(text) == label
                return A_Index
        }
        return false
    }

    static ReloadSettings() {
        data := Config.LoadJson(App.Config.Path)
        environment := data["Python"]["condaEnvironment"]
        data["Keyboard"]["f1Alias"] := 0
        data["Mouse"]["xButtonMapping"] := 0
        data["Mouse"]["reverseHorizontal"] := 0
        data["Mouse"]["winWheelTransparency"] := 1
        data["IME"]["chineseToggle"] := ImeMethods.CtrlSpace
        data["RemoteDesktop"]["capsMode"] := "layer"
        data["Python"]["condaEnvironment"] := "__missing_test_environment__"
        data["Future"] := Map("preserved", 1)
        Config.SaveJson(data, App.Config.Path)
        before := FileRead(App.Config.Path)
        App.Session.SetPaused(true)
        functionKeys := App.Mouse.FunctionKeys
        App.Tray.Invoke("readConfig")
        this.Assert(!App.Settings.f1Alias && !App.Input.Aliases["F1"], "Reload applies F1 alias")
        this.Assert(!App.XButtons.MappingEnabled && !App.MouseSettings.reverseHorizontal
            && App.MouseSettings.winWheelTransparency, "Reload applies mouse preferences")
        this.Assert(App.Ime.Settings.chineseToggle == ImeMethods.CtrlSpace
            && App.CapsPolicy.Settings.capsMode == "layer", "Reload updates shared IME and remote settings")
        this.Assert(App.ScreenKeyboard.Python.Environment == data["Python"]["condaEnvironment"]
            && App.Python.Executable == "", "Reload updates Python launcher in place")
        this.Assert(App.Session.Paused && !App.Input.Enabled && !App.XButtons.Enabled
            && App.Mouse.FunctionKeys == functionKeys, "Reload preserves pause and temporary function-key mode")
        this.Assert(FileRead(App.Config.Path) == before, "Reload does not rewrite JSON")
        f1 := App.Tray.Entries["f1"]
        this.Assert(!(DllCall("GetMenuState", "Ptr", f1.Menu.Handle,
            "UInt", this.MenuHas(f1.Menu, f1.Item.Label) - 1, "UInt", 0x400) & 8), "Reload refreshes F1 check mark")

        data["Keyboard"]["f1Alias"] := 1
        data["Mouse"]["xButtonMapping"] := 9
        Config.SaveJson(data, App.Config.Path)
        invalid := FileRead(App.Config.Path)
        failed := false
        try App.SettingActions.Reload(ObjBindMethod(App, "ApplySettings"))
        catch ValueError
            failed := true
        this.Assert(failed && !App.Settings.f1Alias && !App.MouseSettings.xButtonMapping,
            "Invalid reload restores all previous settings")
        this.Assert(!App.Config.SaveAll() && FileRead(App.Config.Path) == invalid,
            "Unchanged settings do not overwrite a rejected file")

        data["Mouse"]["xButtonMapping"] := 1
        data["Python"]["condaEnvironment"] := environment
        Config.SaveJson(data, App.Config.Path)
        App.Tray.Invoke("readConfig")
        this.Assert(App.Input.Aliases["F1"] && App.XButtons.MappingEnabled && !App.XButtons.IsEnabled(),
            "Reloaded switches respect global pause")
        App.Session.SetPaused(false)
        App.Tray.Refresh()
        this.Assert(App.XButtons.IsEnabled() && FileExist(App.Python.Executable), "Resumed controllers use reloaded preferences")
        App.Config.SaveAll()
        this.Assert(Config.LoadJson(App.Config.Path)["Future"]["preserved"], "Reload preserves unknown JSON fields")
    }

    static CapsBindings() {
        window := Gui(, "Isolated Caps binding test")
        window.Show("NA w240 h80")
        sender := App.Anki.Sender
        keys := this.FakeKeys()
        App.Anki.Sender := keys
        try {
            this.Assert(App.Registry.Resolve("s", 1, window.Hwnd) && !App.Registry.Resolve("s", 2, window.Hwnd), "Screen keyboard only occupies global first layer")
            this.Assert(!App.Registry.Resolve("w", 1, window.Hwnd), "Anki styles do not capture ordinary windows")
            this.Assert(App.Registry.Resolve("e", 1, window.Hwnd) && !App.Registry.Resolve("e", 2, window.Hwnd), "Outside Anki E opens native directory menu only on layer one")
            this.Assert(App.Registry.Resolve("q", 4, window.Hwnd).Mode == "pass", "Outside Anki Q falls back to modifier-preserving Esc")
            this.Assert(App.Registry.Resolve("a", 1, window.Hwnd).Mode == "layers", "Outside Anki A retains default lock toggle")
            this.Assert(App.Registry.Resolve("t", 3, window.Hwnd).Mode == "layers", "Outside Anki T retains third-layer accessor")
            this.Assert(!App.Registry.Resolve("f", 1, window.Hwnd), "No Anki match and no default means no action")
            GroupAdd(WindowGroups.Anki, "ahk_id " window.Hwnd)
            for entry in [["q", 1, "^r"], ["w", 1, "#^{F13}"],
                ["e", 1, "!{F13}"], ["e", 2, "#{F13}"],
                ["r", 1, "^!{F13}"], ["r", 2, "^!+{F13}"], ["t", 1, "^!+{F13}"],
                ["a", 1, "#^+{F13}"], ["a", 2, "#^!{F13}"],
                ["s", 1, "#!{F13}"], ["s", 2, "#!+{F13}"],
                ["d", 1, "^+{F13}"], ["d", 2, "#+{F13}"],
                ["f", 1, "{F13}"], ["f", 2, "+{F13}"],
                ["g", 1, "^{F13}"], ["g", 2, "+{F13}"]] {
                binding := App.Registry.Resolve(entry[1], entry[2], window.Hwnd)
                binding.Callback.Call(HotkeyContext(entry[1], Map(), [], window.Hwnd))
                this.Assert(keys.Last == entry[3], "Anki-specific binding dispatch: " entry[1] " / " entry[2])
            }
            this.Assert(!App.Registry.Resolve("s", 3, window.Hwnd), "Anki does not fall back from undeclared layers")
            this.Assert(!App.Registry.Resolve("q", 2, window.Hwnd), "Anki blank Shift-Q does not send default Esc")
            for layer in [2, 3, 4]
                this.Assert(!App.Registry.Resolve("t", layer, window.Hwnd), "Anki blank T layers do not invoke defaults")
            this.Assert(App.Registry.Resolve("c", 1, window.Hwnd).Mode == "layers", "Keys without Anki overrides retain default copy")
            keys.Last := "unchanged"
            App.Anki.Send("bg_gm")
            this.Assert(keys.Last == "unchanged", "Style with no configured shortcut emits no input")
        } finally {
            App.Anki.Sender := sender
            window.Destroy()
        }
    }

    static MouseCleanup() {
        actions := this.FakeActions()
        mouse := MouseController(AppSettings.Mouse(), actions)
        mouse.SetFunctionKeys(true)
        mouse.MiddleKeyDown("F2")
        mouse.MiddleKeyDown("F2")
        this.Assert(actions.Events.Length == 1 && mouse.MiddleDown, "Middle down ignores auto-repeat")
        mouse.SetEnabled(false)
        this.Assert(actions.Events[2] == "up" && !mouse.MiddleDown, "Pause releases held middle button")
        this.Assert(mouse.CanHandle("F2"), "Paused held key remains captured until release")
        mouse.KeyUp("F2")
        this.Assert(!mouse.CanHandle("F2"), "Release ends capture while paused")
        mouse.SetEnabled(true)
        mouse.MiddleKeyDown("F2")
        mouse.SetFunctionKeys(false)
        this.Assert(actions.Events[4] == "up", "Disabling function keys releases middle button")
        mouse.KeyUp("F2")
        mouse.SetFunctionKeys(true)
        mouse.ScrollKeyDown("F3", "WheelUp")
        mouse.ScrollKeyDown("F3", "WheelUp")
        mouse.KeyUp("F3")
        mouse.ScrollKeyDown("F4", "WheelDown")
        mouse.KeyUp("F4")
        this.Assert(actions.Events.Length == 6, "Scroll keys emit once per press")
        this.Assert(actions.Events[5] == "WheelUp" && actions.Events[6] == "WheelDown", "F3/F4 directions")
        mouse.Horizontal("WheelLeft")
        this.Assert(actions.Events[7] == "WheelRight", "Horizontal direction reversed")
        mouse.MiddleKeyDown("F2")
        mouse.ResetInput()
        this.Assert(actions.Events[-1] == "up" && !mouse.MiddleDown && !mouse.Held.Count && mouse.FunctionKeys, "Reset releases simulated middle and preserves mode")
    }

    static AutorunShortcut() {
        startup := Autorun(App.Root, this.Directory)
        startup.SetEnabled(true)
        FileGetShortcut(startup.Path, &target, &working, &arguments,, &icon)
        this.Assert(target == A_AhkPath, "Shortcut targets current AHK interpreter")
        this.Assert(InStr(arguments, "main.ahk") && SubStr(arguments, 1, 1) == '"', "Shortcut quotes script path")
        this.Assert(InStr(icon, "MainIcon.ico"), "Shortcut uses project icon")
        startup.SetEnabled(false)
        this.Assert(!startup.Enabled, "Shortcut removed from isolated test directory")
    }

    static ScreenKeyboard() {
        pid := App.ScreenKeyboard.Open()
        hwnd := WinWait("ahk_pid " pid,, 10)
        this.Assert(hwnd, "Tkinter keyboard window opens")
        ready := DllCall("OpenEventW", "UInt", 0x100000, "Int", false,
            "Str", "Local\custom-autohotkey-config.screen-keyboard." A_ScriptHwnd ".ready", "Ptr")
        try this.Assert(ready && DllCall("WaitForSingleObject", "Ptr", ready, "UInt", 5000) == 0, "Keyboard publishes its ready window")
        finally {
            if ready
                DllCall("CloseHandle", "Ptr", ready)
        }
        this.Assert(InStr(WinGetTitle("ahk_id " hwnd), "屏幕键盘"), "Keyboard window title")
        this.Assert(App.ScreenKeyboard.Open() == pid, "Repeated menu action reuses window")
        WinMove(10, 10,,, "ahk_id " hwnd)
        duplicate := App.Python.Launch(App.Root "\py\main.py", ["screen-keyboard", "--host", A_ScriptHwnd], App.Root)
        this.Assert(!ProcessWaitClose(duplicate, 10), "Duplicate Python process exits")
        Sleep(200)
        this.Assert(ProcessExist(pid) && WinExist("ahk_id " hwnd), "Original Python process and window survive")
        this.Assert(DllCall("IsWindowVisible", "Ptr", hwnd), "Duplicate launch shows the original window")
        WinGetPos(&x, &y,,, "ahk_id " hwnd)
        this.Assert(x != 10 || y != 10, "Duplicate launch repositions the original window near the cursor")
        App.ScreenKeyboard.Stop()
        this.Assert(!ProcessWaitClose(pid, 5), "Python GUI closes on shutdown")
        pid := App.ScreenKeyboard.Open()
        App.ScreenKeyboard.Stop()
        this.Assert(!ProcessWaitClose(pid, 5), "Shutdown also closes a GUI process still starting")
    }

    static Transparency() {
        window := Gui(, "Transparency test")
        window.Show("w200 h80")
        try {
            WindowActions.AdjustTransparency(-20, window.Hwnd)
            this.Assert(WinGetTransparent("ahk_id " window.Hwnd) == 235, "Wheel down lowers opacity")
            WindowActions.AdjustTransparency(20, window.Hwnd)
            this.Assert(WinGetTransparent("ahk_id " window.Hwnd) == "", "Full opacity disables transparency")
        } finally window.Destroy()
    }

    static PythonArguments() {
        script := this.Directory "\arguments.py"
        output := this.Directory "\arguments.json"
        FileAppend("import json, sys" Chr(10) "from pathlib import Path" Chr(10)
            . "Path(sys.argv[1]).write_text(json.dumps(sys.argv[2:]), encoding='utf-8')", script, "UTF-8-RAW")
        arguments := ["with spaces", 'with "quotes"', "trailing\", 'slash\"quote', "中文参数", ""]
        pid := App.Python.Launch(script, [output, arguments*], this.Directory, false)
        this.Assert(!ProcessWaitClose(pid, 10), "General Python task exits")
        actual := Config.LoadJson(output)
        for value in arguments
            this.Assert(actual[A_Index] == value, "Python argv quoting")
    }

    static Cleanup(*) {
        for name in ["arguments.py", "arguments.json"] {
            if FileExist(this.Directory "\" name)
                FileDelete(this.Directory "\" name)
        }
        if FileExist(this.Directory "\settings.json")
            FileDelete(this.Directory "\settings.json")
        if FileExist(this.Directory "\Custom Autohotkey Config.lnk")
            FileDelete(this.Directory "\Custom Autohotkey Config.lnk")
        if DirExist(this.Directory)
            DirDelete(this.Directory)
    }
}

try {
    AppTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}
