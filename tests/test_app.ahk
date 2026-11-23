#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/config.ahk
#Include ../src/lib/input_rule.ahk
#Include ../src/lib/python.ahk
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/typing.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/lib/text.ahk
#Include ../src/lib/editing.ahk
#Include ../src/lib/window.ahk
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
#Include ../src/actions/diagnosis.ahk
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
#Include ../src/actions/window_inspector_launcher.ahk
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
#Include ../src/rules/setting_inputs.ahk
#Include ../src/ui/dpi_gui.ahk
#Include ../src/ui/settings_input.ahk
#Include ../src/ui/tray.ahk
#Include ../src/ui/popup_menu.ahk
#Include ../src/core/app.ahk
#Include ../src/core/runtime_errors.ahk

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
        if A_Args.Length && A_Args[1] == "--live-keyboard-launch" {
            this.ScreenKeyboardHotkey()
            FileAppend("PASS: CapsLock+S and F24+S displayed the keyboard via the running main script`n", "*")
            return
        }
        App.Start(this.Directory, A_ScriptDir "\..")
        OnExit(ObjBindMethod(this, "Cleanup"))
        this.Assert(this.MenuHas(A_TrayMenu, "快捷路径与系统工具") == this.MenuHas(A_TrayMenu, "屏幕键盘") + 1,
            "Path menu follows the on-screen keyboard in the tray")
        toolsIndex := this.MenuHas(A_TrayMenu, "其他工具")
        this.Assert(toolsIndex == this.MenuHas(A_TrayMenu, "快捷路径与系统工具") + 1, "Tools follow the path menu")
        toolsMenu := DllCall("GetSubMenu", "Ptr", A_TrayMenu.Handle, "Int", toolsIndex - 1, "Ptr")
        localTools := App.Tray.Entries["windowInspector"].Menu
        this.Assert(toolsMenu == localTools.Handle, "Local inspector stays in the tools submenu")
        heading := this.MenuHas(localTools, " 以下为 PersonalScripts 工具")
        this.Assert(heading == this.MenuHas(localTools, "窗口信息查看器") + 2
            && DllCall("GetMenuState", "Ptr", toolsMenu, "UInt", heading - 2, "UInt", 0x400) & 0x800
            && DllCall("GetMenuState", "Ptr", toolsMenu, "UInt", heading - 1, "UInt", 0x400) & 3,
            "A separator and disabled PersonalScripts heading follow the inspector")
        for id in ["unicodeInspector", "keyboardRemapper", "systemEventViewer", "imageOcr", "matrixViewer", "rcloneSync", "runScript"]
            this.Assert(toolsMenu == App.Tray.Entries[id].Menu.Handle, "Tool is directly in the tools submenu: " id)
        scripts := App.Tray.Entries["runScript"].Menu
        syncIndex := this.MenuHas(scripts, "rclone-sync")
        this.Assert(this.MenuHas(scripts, "run-script 启动器") == syncIndex + 2
            && DllCall("GetMenuState", "Ptr", toolsMenu, "UInt", syncIndex, "UInt", 0x400) & 0x800,
            "A separator groups the launcher below rclone-sync")
        this.LayerKeySettings()
        if A_Args.Length && A_Args[1] == "--settings-only" {
            this.ReloadSettings()
            this.InputDialogs()
            App.Stop()
            FileAppend("PASS: " this.Count " settings assertions`n", "*", "UTF-8")
            return
        }
        if A_Args.Length && A_Args[1] == "--keyboard-only" {
            this.ScreenKeyboard()
            App.Stop()
            FileAppend("PASS: " this.Count " screen keyboard app assertions`n", "*", "UTF-8")
            return
        }
        this.Assert(InStr(A_IconFile, "MainIcon.ico"), "Normal icon loaded")
        this.Assert(A_TrayMenu.Default == "&Open", "Default tray action opens native AHK window")
        for id in ["mouse", "config", "readConfig"]
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
        this.Assert(!App.Input.AliasEnabled("CapsLock"), "Paused Caps alias passes through")
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

    static LayerKeySettings() {
        other := App.Tray.Entries["reverse"].Menu
        submenu := DllCall("GetSubMenu", "Ptr", other.Handle, "Int", this.MenuHas(other, "Layer 键设置") - 1, "Ptr")
        this.Assert(other.Handle == DllCall("GetSubMenu", "Ptr", A_TrayMenu.Handle, "Int",
            this.MenuHas(A_TrayMenu, "其他设置") - 1, "Ptr"), "Layer key settings are under Other settings")
        for key, property in CapsPolicy.ConfigurableAliases {
            id := StrLower(key), otherKey := key == "F1" ? "F24" : "F1"
            entry := App.Tray.Entries[id]
            this.Assert(submenu == entry.Menu.Handle && App.Input.AliasEnabled(key), "Layer alias enabled in submenu: " key)
            App.Tray.Invoke(id)
            flags := DllCall("GetMenuState", "Ptr", submenu, "UInt", this.MenuHas(entry.Menu, entry.Item.Label) - 1, "UInt", 0x400)
            this.Assert(!(flags & 8) && !App.Input.AliasEnabled(key) && App.Input.AliasEnabled(otherKey)
                && Config.LoadJson(App.Config.Path)["Keyboard"][property] == 0, "Layer alias independently disabled and saved: " key)
            App.Tray.Invoke(id)
        }
        App.Triggers.Down("CapsLock", A_ScriptHwnd)
        for key in CapsPolicy.ConfigurableAliases
            App.Tray.Invoke(StrLower(key))
        this.Assert(!App.State.Active && App.Triggers.Held.Has("CapsLock"), "Disabling a held Layer keeps the release captured")
        App.Input.EndAlias("CapsLock", A_ScriptHwnd, Map())
        App.Tray.Invoke("readConfig")
        for key in ["CapsLock", "F1", "F24"]
            this.Assert(!App.Input.AliasEnabled(key), "All physical triggers disabled: " key)
        this.NativeLayerKeys()
        for key in CapsPolicy.ConfigurableAliases
            App.Tray.Invoke(StrLower(key))
        this.Assert(!App.Input.Aliases.Has("F6"), "F6 stays available to the foreground application")
        this.CapturedLayerKeys()
        data := Config.LoadJson(App.Config.Path)
        data["Keyboard"]["f24Alias"] := 0
        Config.SaveJson(data, App.Config.Path)
        App.Tray.Invoke("readConfig")
        this.Assert(!App.Input.AliasEnabled("F24"), "Reload disables F24")
        data["Keyboard"].Delete("f24Alias")
        data["Keyboard"].Delete("capsLockAlias")
        Config.SaveJson(data, App.Config.Path)
        App.Tray.Invoke("readConfig")
        this.Assert(App.Input.AliasEnabled("CapsLock") && App.Input.AliasEnabled("F24") && !App.Input.Aliases.Has("F23"), "Missing settings default to CapsLock and F24")
        App.Config.SaveAll()
    }

    static CapturedLayerKeys() {
        window := Gui(, "Layer key capture test"), edit := window.AddEdit("w200")
        events := [], taps := [], originalTap := App.Input.Tap, level := A_SendLevel
        wasLocked := GetKeyState("CapsLock", "T")
        record := ObjBindMethod(this, "RecordLayerKey", events, edit.Hwnd)
        try {
            window.Show()
            edit.Focus()
            this.Assert(WinWaitActive(window.Hwnd,, 1), "Layer key capture target has focus")
            App.Input.Tap := ObjBindMethod(taps, "Push")
            for msg in [0x100, 0x101, 0x104, 0x105]
                OnMessage(msg, record)
            SendLevel(1)
            for key in App.Input.Aliases {
                count := taps.Length
                SendEvent("{Blind}{" key " down}")
                Sleep(40)
                this.Assert(App.State.Held.Has(key), "Hook captured the Layer press: " key)
                SendEvent("{Blind}{" key " down}{" key " up}")
                Sleep(40)
                this.Assert(taps.Length == count + 1, "Repeated key-down produces one Layer tap: " key)
                SendEvent("{Blind}{" key " down}")
                Sleep(40)
                SendEvent("{Blind}{2 down}")
                Sleep(40)
                SendEvent("{Blind}{2 up}")
                Sleep(40)
                this.Assert(App.State.Used, "Layer action ran while the trigger was held: " key)
                App.Input.SetAliasEnabled(key, false)
                SendEvent("{Blind}{" key " down}")
                SendEvent("{Blind}{" key " up}")
                Sleep(40)
                this.Assert(!App.State.Held.Count && taps.Length == count + 1, "Used Layer releases without a tap: " key)
                this.Assert(!events.Length, "Target received a captured Layer event: " key)
                this.Assert(GetKeyState("CapsLock", "T") == wasLocked, "Layer input preserves CapsLock state")
                this.Assert(!App.Input.AliasEnabled(key), "Disabled hook finishes the captured press: " key)
                App.Input.SetAliasEnabled(key, true)
            }
        } finally {
            for key in App.State.Held.Clone()
                SendEvent("{Blind}{" key " up}")
            SendLevel(level)
            for msg in [0x100, 0x101, 0x104, 0x105]
                OnMessage(msg, record, 0)
            App.Input.Tap := originalTap
            if GetKeyState("CapsLock", "T") != wasLocked
                SetCapsLockState(wasLocked)
            window.Destroy()
        }
    }

    static NativeLayerKeys() {
        window := Gui(, "Layer input test"), edit := window.AddEdit("w200")
        window.Show()
        events := [], tap := App.Input.Tap, taps := []
        record := ObjBindMethod(this, "RecordLayerKey", events, edit.Hwnd)
        previousLevel := A_SendLevel, wasLocked := GetKeyState("CapsLock", "T")
        try {
            App.Input.Tap := ObjBindMethod(taps, "Push")
            edit.Focus()
            this.Assert(WinWaitActive(window.Hwnd,, 1), "Isolated input target has focus")
            OnMessage(0x100, record), OnMessage(0x101, record)
            ; 有正式实例时让原生事件避开它的 I0 钩子；独立运行时同时经过测试实例的钩子。
            SplitPath(A_ScriptDir,, &root)
            previousHidden := A_DetectHiddenWindows
            DetectHiddenWindows(true)
            try resident := WinExist(root "\main.ahk ahk_class AutoHotkey")
            finally DetectHiddenWindows(previousHidden)
            SendLevel(resident ? 0 : 1)
            for key in App.Input.Aliases {
                events.Length := 0
                SendEvent("{Blind}{" key " down}")
                Sleep(40)
                this.Assert(!App.State.Active, "Disabled key uses native input: " key)
                if key == "CapsLock"
                    this.Assert(GetKeyState(key, "T") != wasLocked, "Windows handles native CapsLock toggle")
                SendEvent("{Blind}{" key " up}")
                Sleep(40)
                this.Assert(events.Length == 2 && events[1].Key == key && events[1].Msg == 0x100
                    && events[2].Key == key && events[2].Msg == 0x101 && !taps.Length,
                    "Native window receives disabled key down and up exactly once: " key)
            }
        } finally {
            OnMessage(0x100, record, 0), OnMessage(0x101, record, 0)
            if GetKeyState("CapsLock")
                SendEvent("{Blind}{CapsLock up}")
            SetCapsLockState(wasLocked)
            SendLevel(previousLevel)
            App.Input.Tap := tap
            window.Destroy()
        }
    }

    static RecordLayerKey(events, edit, vk, flags, msg, hwnd) {
        if hwnd == edit {
            key := GetKeyName(Format("vk{:02X}", vk))
            if App.Input.Aliases.Has(key)
                events.Push({Key: key, Msg: msg})
        }
    }

    static InputDialogs() {
        this.TextDialogLayout()
        for key, group in Map("pointerFastStep", App.MouseSettings, "wheelMultiplier", App.MouseSettings,
            "passThroughOpacityPercent", App.WindowSettings, "condaEnvironment", App.PythonSettings, "launcherPath", App.PersonalScriptsSettings) {
            entry := App.Tray.Entries[key]
            this.Assert(entry.Menu != A_TrayMenu, "Editor is in settings submenu: " key)
            App.Tray.Invoke(key)
            hwnd := WinWait(RTrim(entry.Item.Label, "…") " ahk_class AutoHotkeyGUI ahk_pid " ProcessExist(),, 1)
            this.Assert(hwnd && ControlGetText("Edit1", hwnd) == String(group.%key%), "Editor starts with current value: " key)
            before := FileRead(App.Config.Path)
            if key == "passThroughOpacityPercent" {
                this.Assert(InStr(WinGetText(hwnd), "0–100") && ControlGetHwnd("msctls_updown321", hwnd), "Spin box shows range")
                original := Integer(ControlGetText("Edit1", hwnd))
                ControlSend("{Up}", "Edit1", hwnd)
                this.Assert(ControlGetText("Edit1", hwnd) == original + 1, "Spin arrow increments current value")
                this.InvalidInput(hwnd, "101", before)
                ControlSetText("0", "Edit1", hwnd)
                ControlClick("确定", hwnd)
                this.Assert(WinWaitClose(hwnd,, 1) && App.Windows.PassOpacity == 0
                    && Config.LoadJson(App.Config.Path)["Window"][key] == 0, "Corrected zero is applied and saved")
            } else if key == "condaEnvironment" {
                this.InvalidInput(hwnd, "a/b", before)
                ControlSetText("unsaved", "Edit1", hwnd)
                ControlSend("{Escape}", "Edit1", hwnd)
                this.Assert(WinWaitClose(hwnd,, 1) && FileRead(App.Config.Path) == before, "Escape discards text")
                App.Tray.Invoke(key)
                hwnd := WinWait(RTrim(entry.Item.Label, "…") " ahk_class AutoHotkeyGUI ahk_pid " ProcessExist(),, 1)
                ControlSetText("tray-test-env", "Edit1", hwnd)
                ControlSend("{Enter}", "Edit1", hwnd)
                this.Assert(WinWaitClose(hwnd,, 1) && App.Python.Environment == "tray-test-env"
                    && Config.LoadJson(App.Config.Path)["Python"][key] == "tray-test-env", "Enter applies and persists text")
            } else if key == "launcherPath" {
                this.InvalidInput(hwnd, "missing", before)
                path := this.Directory "\run-script.ps1"
                FileAppend("", path)
                ControlSetText(path, "Edit1", hwnd)
                ControlClick("确定", hwnd)
                this.Assert(WinWaitClose(hwnd,, 1) && App.PersonalScriptsSettings.launcherPath == path, "Existing launcher path accepted")
                App.Tray.Invoke(key)
                hwnd := WinWait(RTrim(entry.Item.Label, "…") " ahk_class AutoHotkeyGUI ahk_pid " ProcessExist(),, 1)
                ControlSetText("", "Edit1", hwnd)
                ControlClick("确定", hwnd)
                this.Assert(WinWaitClose(hwnd,, 1) && App.PersonalScriptsSettings.launcherPath == "", "Empty path restores PATH lookup")
            } else {
                ControlSetText("23", "Edit1", hwnd)
                if key == "wheelMultiplier"
                    PostMessage(0x0010, 0, 0,, hwnd) ; WM_CLOSE
                else
                    ControlClick("取消", hwnd)
                this.Assert(WinWaitClose(hwnd,, 1) && FileRead(App.Config.Path) == before, "Cancel or close does not save: " key)
            }
        }
        rule := InputRule.Integer(1, 10, Map(2, true, 3, true, 4, true), (n) => Mod(n, 2) == 0, "只接受偶数")
        this.Assert(rule.Parse("4") == 4, "Range, set and predicate accept matching integer")
        for raw in ["0", "1", "3", "11", "2.5", "abc", "18446744073709551618"] {
            rejected := false
            try rule.Parse(raw)
            catch ValueError
                rejected := true
            this.Assert(rejected, "Numeric validator rejects " raw)
        }
    }

    static TextDialogLayout() {
        line := ""
        loop 18
            line .= "long-path-segment\"
        for multiline in [false, true] {
            for wrap in [true, false] {
                rule := InputRule.Text("输入测试", "", 0, multiline, wrap)
                dialog := SettingsInputDialog("文本布局测试", rule), saved := []
                dialog.Open(line, ObjBindMethod(saved, "Push"))
                try {
                    Sleep(40)
                    hwnd := dialog.Gui.Hwnd, input := dialog.Input.Hwnd
                    this.Assert(WinGetStyle(hwnd) & 0x40000, "Text dialog has a sizing frame")
                    limits := Buffer(40, 0)
                    SendMessage(0x24, 0, limits.Ptr,, hwnd) ; WM_GETMINMAXINFO
                    this.Assert(NumGet(limits, 24, "Int") >= dialog.Dpi.Px(SettingsInputDialog.TextMinWidth)
                        && NumGet(limits, 28, "Int") >= dialog.Dpi.Px(SettingsInputDialog.TextMinHeight), "Minimum tracking size is enforced")
                    this.Assert((SendMessage(0xBA, 0, 0, input) > 1) == wrap, "Visual line count follows wrap option")
                    dialog.Input.GetPos(,, &oldWidth, &oldHeight)
                    dialog.Gui.GetClientPos(,, &w, &h)
                    dialog.Gui.Show("w" (w + 110) " h" (h + 50))
                    Sleep(60)
                    dialog.Input.GetPos(,, &newWidth, &newHeight)
                    dialog.Gui.GetClientPos(,, &newW, &newH)
                    this.Assert(newWidth > oldWidth && newHeight > oldHeight && newWidth - oldWidth == newW - w
                        && newHeight - oldHeight == newH - h, "Text editor follows both window dimensions")
                    this.Assert(dialog.Input.Text == line, "Soft wrapping leaves the setting unchanged")
                    if multiline {
                        ControlSetText("first", input)
                        SendMessage(0xB1, 5, 5, input) ; EM_SETSEL
                        ControlSend("{Enter}", input)
                        ControlSendText("second", input)
                        Sleep(60)
                        this.Assert(dialog.Gui && StrReplace(dialog.Input.Text, "`r") == "first`nsecond",
                            "Multiline Enter inserts a hard break: " (dialog.Gui ? dialog.Input.Text : "closed"))
                        ControlClick("确定", hwnd)
                    } else {
                        rejected := false
                        try rule.Parse("first`r`nsecond")
                        catch ValueError
                            rejected := true
                        this.Assert(rejected, "Single-line rule rejects pasted line breaks")
                        ControlSend("{Enter}", input)
                    }
                    this.Assert(WinWaitClose(hwnd,, 1) && saved.Length == 1
                        && StrReplace(saved[1], "`r") == (multiline ? "first`nsecond" : line), "Saved value matches logical lines")
                } finally {
                    if dialog.Gui
                        dialog.Close()
                }
            }
        }
    }

    static InvalidInput(hwnd, raw, before) {
        ControlSetText(raw, "Edit1", hwnd)
        this.WarningSeen := false
        dismiss := ObjBindMethod(this, "DismissInputWarning", hwnd, A_TickCount + 3000)
        SetTimer(dismiss, 30)
        try {
            ControlClick("确定", hwnd)
            deadline := A_TickCount + 3000
            while !this.WarningSeen && A_TickCount < deadline
                Sleep(20)
        } finally SetTimer(dismiss, 0)
        this.Assert(this.WarningSeen && WinExist(hwnd) && ControlGetText("Edit1", hwnd) == raw
            && FileRead(App.Config.Path) == before, "Warning preserves rejected input and saved config: " raw)
    }

    static DismissInputWarning(owner, deadline) {
        if hwnd := WinExist("ahk_class #32770 ahk_pid " ProcessExist()) {
            if DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr") == owner {
                this.WarningSeen := true
                PostMessage(0x00F5, 0, 0, "Button1", hwnd) ; BM_CLICK
                return
            }
        }
        if A_TickCount > deadline {
            FileAppend("Timed out waiting for settings warning`n", "**")
            ExitApp(1)
        }
    }

    static ReloadSettings() {
        data := Config.LoadJson(App.Config.Path)
        environment := data["Python"]["condaEnvironment"]
        data["Keyboard"]["f1Alias"] := 0
        this.Assert(data["Window"]["passThroughOpacityPercent"] == 59 && App.Windows.PassOpacity == 150, "Default pass-through opacity round-trips")
        data["Window"]["passThroughOpacityPercent"] := 42
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
        this.Assert(App.Windows.PassOpacity == 107, "Reload applies configured pass-through opacity")
        this.Assert(!App.XButtons.MappingEnabled && !App.MouseSettings.reverseHorizontal
            && App.MouseSettings.winWheelTransparency, "Reload applies mouse preferences")
        this.Assert(App.Ime.Settings.chineseToggle == ImeMethods.CtrlSpace
            && App.CapsPolicy.Settings.capsMode == "layer", "Reload updates shared IME and remote settings")
        this.Assert(App.PersonalTools.Python.Environment == data["Python"]["condaEnvironment"]
            && App.Python.Executable == "", "Reload updates Python launcher in place")
        this.Assert(App.Session.Paused && !App.Input.Enabled && !App.XButtons.Enabled
            && App.Mouse.FunctionKeys == functionKeys, "Reload preserves pause and temporary function-key mode")
        this.Assert(FileRead(App.Config.Path) == before, "Reload does not rewrite JSON")
        f1 := App.Tray.Entries["f1"]
        this.Assert(!(DllCall("GetMenuState", "Ptr", f1.Menu.Handle,
            "UInt", this.MenuHas(f1.Menu, f1.Item.Label) - 1, "UInt", 0x400) & 8), "Reload refreshes F1 check mark")

        for invalidPercent in [-1, 101, 59.5, "59"] {
            data["Window"]["passThroughOpacityPercent"] := invalidPercent
            Config.SaveJson(data, App.Config.Path)
            rejected := false
            try App.SettingActions.Reload(ObjBindMethod(App, "ApplySettings"))
            catch ValueError
                rejected := true
            this.Assert(rejected && App.Windows.PassOpacity == 107, "Invalid pass-through opacity preserves last good setting")
        }
        data["Window"]["passThroughOpacityPercent"] := 42

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
            this.Assert(App.Registry.Resolve("w", 1, window.Hwnd).Mode == "once", "Outside Anki W opens the window inspector")
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
        this.ScreenKeyboardArguments()
        this.ScreenKeyboardHotkey(true)
        trayAction := App.Tray.Entries["keyboard"].Item.Action
        this.Assert(App.Registry.Resolve("s", 1).Callback == trayAction, "Caps+S and the tray use the same external launcher")
        pid := trayAction.Call()
        try {
            ; 外部单实例可能已经在运行，仅关闭本测试实际创建的窗口。
            hwnd := WinWait("Screen Keyboard ahk_class TkTopLevel",, 8)
            this.Assert(pid && hwnd, "PersonalScripts screen keyboard opened")
            duplicate := trayAction.Call()
            this.Assert(duplicate && !ProcessWaitClose(duplicate, 5) && WinExist(hwnd), "External launcher reuses its window")
            this.ScreenKeyboardInput()
        } finally {
            if pid && (owned := WinExist("Screen Keyboard ahk_class TkTopLevel ahk_pid " pid))
                WinClose(owned)
        }
    }

    static ScreenKeyboardArguments() {
        tools := App.PersonalTools, settings := App.Settings
        try {
            App.Settings := AppSettings.Keyboard()
            App.PersonalTools := {Launch: (self, script, args) => args}
            launch := App.Tray.Entries["keyboard"].Item.Action
            for key in ["F24", "CapsLock", "F1"] {
                args := launch.Call()
                this.Assert(args.Length == 1 && args[1] == "--force-layer=" key,
                    "Screen keyboard follows the enabled Layer alias: " key)
                property := CapsPolicy.ConfigurableAliases[key]
                App.Settings.%property% := false
            }
            this.Assert(!launch.Call().Length, "All aliases disabled leaves the keyboard preference in effect")
        } finally {
            App.Settings := settings
            App.PersonalTools := tools
        }
    }

    static ScreenKeyboardHotkey(testTray := false) {
        title := "Screen Keyboard ahk_class TkTopLevel"
        existing := WinExist(title)
        keyboard := 0
        target := Gui(, "Screen keyboard launch test")
        edit := target.AddEdit("w260")
        originalLevel := A_SendLevel
        try {
            target.Show("Maximize")
            edit.Focus()
            this.Assert(WinWaitActive(target.Hwnd,, 2), "Launch test has foreground focus")
            SendLevel(1)
            for key in (testTray ? ["tray", "F24", "CapsLock"] : ["F24", "CapsLock"]) {
                if shown := WinExist(title)
                    WinHide(shown)
                this.Assert(!WinExist(title), "Keyboard is absent or hidden before " key "+S")
                if key == "tray" {
                    position := this.MenuHas(A_TrayMenu, "屏幕键盘") - 1
                    command := DllCall("GetMenuItemID", "Ptr", A_TrayMenu.Handle, "Int", position, "UInt")
                    PostMessage(0x111, command, 0,, A_ScriptHwnd) ; WM_COMMAND from the native menu
                } else {
                    SendEvent("{Blind}{" key " down}")
                    try {
                        Sleep(50)
                        SendEvent("{Blind}{s down}")
                        Sleep(45)
                        SendEvent("{Blind}{s up}")
                    } finally SendEvent("{Blind}{" key " up}")
                }
                keyboard := WinWait(title,, 5)
                inFront := keyboard && this.KeyboardInFront(keyboard)
                this.Assert(inFront && (!shown || keyboard == shown)
                    && WinActive(target.Hwnd) && edit.Value == "",
                    key " must display the keyboard above the focused target (in front=" inFront ", focus="
                    . (!!WinActive(target.Hwnd)) ", style=" (keyboard ? Format("{:x}", WinGetExStyle(keyboard)) : "") ", edit=" edit.Value ")")
            }
        } finally {
            SendLevel(originalLevel)
            if existing && DllCall("IsWindow", "Ptr", existing) && !DllCall("IsWindowVisible", "Ptr", existing)
                WinShow(existing)
            if !existing && (owned := WinExist(title)) {
                WinClose(owned)
                WinWaitClose(owned,, 3)
            }
            target.Destroy()
        }
    }

    static KeyboardInFront(hwnd) {
        deadline := A_TickCount + 2500
        loop {
            WinGetPos(&x, &y, &w, &h, hwnd)
            point := ((y + h // 2) << 32) | ((x + w // 2) & 0xffffffff)
            hit := DllCall("WindowFromPoint", "Int64", point, "Ptr")
            ; Tk temporarily maps a normal window before configuring its nonactivating keyboard.
            styles := 0x08000000 | 0x8 ; WS_EX_NOACTIVATE | WS_EX_TOPMOST
            if DllCall("GetAncestor", "Ptr", hit, "UInt", 2, "Ptr") == hwnd && (WinGetExStyle(hwnd) & styles) == styles
                return true
            Sleep(50)
        } until A_TickCount >= deadline
        return false
    }

    static ScreenKeyboardInput() {
        target := Gui(, "Screen keyboard input test"), edit := target.AddEdit("w320")
        layers := [], callbacks := []
        try {
            loop 4 {
                action := App.Registry.Resolve("2", A_Index)
                callbacks.Push(action.Callback)
                action.Callback := ObjBindMethod(this, "RecordScreenLayer", layers)
            }
            target.Show()
            WinActivate(target.Hwnd)
            this.Assert(WinWaitActive(target.Hwnd,, 2), "Native keyboard test has focus")
            edit.Focus()
            script := App.PersonalTools.ResolveScript("tools\others\screen-keyboard.py")
            pid := App.Python.Launch(A_ScriptDir "\personal_keyboard_input.py", [script.Script, target.Hwnd], App.Root, false)
            this.Assert(!ProcessWaitClose(pid, 8), "External keyboard input probe finished")
            actual := ""
            for layer in layers
                actual .= layer
            this.Assert(actual == "112233444" && edit.Value == "" && !App.State.Active,
                "External SendInput repeats all four layers without typing the bound key: " actual)
            this.Assert(!GetKeyState("LShift") && !GetKeyState("LAlt"), "Onscreen modifiers released during an action stay up")
        } finally {
            for layer, callback in callbacks
                App.Registry.Resolve("2", layer).Callback := callback
            target.Destroy()
        }
    }

    static RecordScreenLayer(layers, context) {
        layers.Push(context.Layer)
        if layers.Length == 9
            Sleep(300) ; 让键盘在最后一次动作返回前松开修饰键。
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
        for name in ["arguments.py", "arguments.json", "run-script.ps1", "settings.json", "Custom Autohotkey Config.lnk"] {
            if FileExist(this.Directory "\" name)
                FileDelete(this.Directory "\" name)
        }
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
