; 组装配置、热键系统与托盘。
class App {
    static Start(directory := AppSettings.GetDirectory(), root := A_ScriptDir) {
        this.Root := root
        this.ConfigDirectory := directory
        SetWorkingDir(root)
        FileEncoding("UTF-8")
        A_MenuMaskKey := "vkE8"
        Thread("Interrupt", 0)
        TraySetIcon(root "\res\MainBusy.ico",, false)
        A_IconTip := "Custom Autohotkey Config · 启动中"
        this.Config := Config.Manager("settings.json", directory)
        this.Settings := this.Config.Register(AppSettings.Keyboard(), "Keyboard")
        this.MouseSettings := this.Config.Register(AppSettings.Mouse(), "Mouse")
        this.PythonSettings := this.Config.Register(AppSettings.Python(), "Python")
        this.PersonalScriptsSettings := this.Config.Register(AppSettings.PersonalScripts(), "PersonalScripts")
        this.RemoteSettings := this.Config.Register(AppSettings.RemoteDesktop(), "RemoteDesktop")
        this.ImeSettings := this.Config.Register(AppSettings.IME(), "IME")
        this.Config.LoadAll()
        this.Python := PythonRuntime(this.PythonSettings.condaEnvironment)
        this.ScreenKeyboard := ScreenKeyboard(this.Python, root)
        this.Autorun := Autorun(root)
        this.Tooltip := TooltipPresenter()
        this.Errors := RuntimeErrors(this.Tooltip)
        this.State := LayerState()
        this.Registry := HotkeyRegistry(ObjBindMethod(WindowGroups, "Matches"))
        this.Sender := KeyboardSender()
        this.ImeApi := ImeApi()
        this.Ime := ImeActions(this.ImeSettings, this.ImeApi, this.Sender, this.Tooltip)
        this.Diagnostics := HotkeyDiagnostics(this.Tooltip)
        this.Anki := AnkiStyles(this.Sender, this.Tooltip)
        this.MouseSender := MouseSender(this.Sender)
        this.Clipboard := ClipboardService(this.Sender)
        this.PersonalTools := PersonalScripts(this.Python, this.PersonalScriptsSettings, ObjBindMethod(this.Config, "SaveAll"))
        this.UnicodeInspector := UnicodeInspectorActions(this.PersonalTools, this.Clipboard)
        this.Typer := TextTyper(this.Sender, this.ImeApi)
        this.Editor := TextEditor(this.Sender, this.Clipboard)
        this.ClipboardActions := ClipboardActions(this.Clipboard, this.Typer, this.Sender, this.Tooltip)
        this.TextActions := TextActions(this.Editor, this.Clipboard, this.Sender, this.Tooltip)
        this.Pointer := PointerActions(this.MouseSender, this.MouseSettings)
        this.Windows := WindowActions(this.Tooltip)
        this.WindowInspector := WindowInspectorLauncher(root, this.Tooltip)
        this.Keys := KeyboardActions(this.Sender, this.Tooltip)
        this.PathActions := PathMenuActions(this.Tooltip, ObjBindMethod(ShellTools, "Open"))
        this.Wheel := WheelActions(this.MouseSender, this.Sender, this.Tooltip, this.MouseSettings)
        this.Touchpad := TouchpadActions(TouchInjection(), this.Tooltip)
        this.Dispatcher := HotkeyDispatcher(this.State, this.Registry, this.Sender)
        WindowGroups.Register()
        this.CapsPolicy := CapsPolicy(this.RemoteSettings)
        this.VirtualKeyboard := VirtualKeyboardInput(this.Registry, this.Sender,
            ObjBindMethod(this.CapsPolicy, "Resolve"), ObjBindMethod(this.Ime, "ToggleLanguage"))
        this.ScreenKeyboard.Connect(this.VirtualKeyboard)
        this.Triggers := TriggerRouter(this.State, this.Sender, ObjBindMethod(this.CapsPolicy, "Resolve"))
        this.Input := HotkeyInput(this.State, this.Registry, this.Dispatcher, this.Triggers,
            CapsPolicy.Aliases(this.Settings.f1Alias), ObjBindMethod(this.Ime, "ToggleLanguage"))
        this.Paths := PopupMenuView(PathMenuBindings.Create(root), ObjBindMethod(this.PathActions, "Open"))
        HotkeyBindings.Register(this.Registry, this.Diagnostics, this.Ime, this.ScreenKeyboard, this.Anki, this.Touchpad, this.Wheel,
            this.Sender, this.ClipboardActions, this.TextActions, this.MouseSender, this.Pointer, this.Windows, this.Keys, this.Paths, this.UnicodeInspector, this.WindowInspector)
        this.Input.Start()
        this.Mouse := MouseController(this.MouseSettings, this.MouseSender)
        this.WindowAutomation := WindowAutomation(this.Sender)
        this.XButtonActions := XButtonActions(this.Sender, CajViewerActions(this.WindowAutomation), PowerIsoActions(this.WindowAutomation), this.Tooltip)
        this.XButtons := XButtonController(this.XButtonActions, this.Tooltip, this.MouseSettings.xButtonMapping)
        this.MiddleDrag := MiddleDragController(this.Sender, ObjBindMethod(MiddleDragPolicy, "Resolve"))
        this.MouseNative := NativeHotkeys()
        MouseBindings.Register(this.MouseNative, this.Mouse, this.XButtons, this.MiddleDrag, this.Input, this.Wheel, this.Windows)
        this.Session := HotkeySession(this.Tooltip, this.Input, this.Mouse, this.XButtons, this.MiddleDrag, this.Touchpad, this.ScreenKeyboard)
        this.SettingActions := SettingsActions(this.Config)
        this.CreateTray()
        this.ExitCallback := ObjBindMethod(this, "Stop")
        OnExit(this.ExitCallback)
        this.Config.SaveAll()
        this.Errors.Start()
        Persistent()
    }

    static CreateTray() {
        commands := Map(
            "keyboard", ObjBindMethod(this.ScreenKeyboard, "Open"),
            "f1", ObjBindMethod(this.SettingActions, "Toggle", this.Settings, "f1Alias", ObjBindMethod(this.Input, "SetAliasEnabled", "F1")),
            "mouse", ObjBindMethod(this.Mouse, "ToggleFunctionKeys"),
            "xbuttons", ObjBindMethod(this.SettingActions, "Toggle", this.MouseSettings, "xButtonMapping", ObjBindMethod(this.XButtons, "SetMappingEnabled")),
            "reverse", ObjBindMethod(this.SettingActions, "Toggle", this.MouseSettings, "reverseHorizontal"),
            "transparency", ObjBindMethod(this.SettingActions, "Toggle", this.MouseSettings, "winWheelTransparency"),
            "autorun", ObjBindMethod(this.Autorun, "Toggle"),
            "config", ObjBindMethod(ApplicationActions, "OpenPath", this.ConfigDirectory),
            "readConfig", ObjBindMethod(this.SettingActions, "Reload", ObjBindMethod(this, "ApplySettings")),
            "help", ObjBindMethod(ApplicationActions, "OpenPath", this.Root "\README.md"),
            "pause", ObjBindMethod(this.Session, "Toggle"),
            "resetHooks", ObjBindMethod(this.Session, "ResetHooks", ObjBindMethod(NativeHotkeys, "ResetHooks")))
        checks := Map(
            "f1", ObjBindMethod(SettingsActions, "Read", this.Settings, "f1Alias"),
            "mouse", ObjBindMethod(this.Mouse, "FunctionKeysEnabled"),
            "xbuttons", ObjBindMethod(SettingsActions, "Read", this.MouseSettings, "xButtonMapping"),
            "reverse", ObjBindMethod(SettingsActions, "Read", this.MouseSettings, "reverseHorizontal"),
            "transparency", ObjBindMethod(SettingsActions, "Read", this.MouseSettings, "winWheelTransparency"),
            "autorun", ObjBindMethod(this.Autorun, "IsEnabled"),
            "pause", ObjBindMethod(this.Session, "IsPaused"))
        for mode in ["layer", "CapsLock", "F1", "F24"] {
            commands["remote/" mode] := ObjBindMethod(this.SettingActions, "Set", this.RemoteSettings, "capsMode", mode)
            checks["remote/" mode] := ObjBindMethod(SettingsActions, "Equals", this.RemoteSettings, "capsMode", mode)
        }
        for property, methods in Map("chineseToggle", ImeMethods.ChineseToggle, "chinesePunctuation", ImeMethods.ChinesePunctuation,
            "koreanToggle", ImeMethods.KoreanToggle, "japaneseToggle", ImeMethods.JapaneseToggle) {
            for method in methods {
                id := "ime/" property "/" method
                commands[id] := ObjBindMethod(this.SettingActions, "Set", this.ImeSettings, property, method)
                checks[id] := ObjBindMethod(SettingsActions, "Equals", this.ImeSettings, property, method)
            }
        }
        this.Tray := TrayView(this.Root, TrayBindings.Create(commands, checks), checks["pause"])
    }

    static ApplySettings() {
        this.Input.SetAliasEnabled("F1", this.Settings.f1Alias)
        this.XButtons.SetMappingEnabled(this.MouseSettings.xButtonMapping)
        if this.Python.Environment != this.PythonSettings.condaEnvironment
            this.Python.SetEnvironment(this.PythonSettings.condaEnvironment)
    }

    static Stop(*) {
        this.Tooltip.Hide()
        for controller in [this.Input, this.Mouse, this.XButtons, this.MiddleDrag,
            this.Touchpad, this.MouseNative, this.ScreenKeyboard, this.Windows] {
            try controller.Stop()
            catch Error as err
                this.Errors.Report(err)
        }
        try this.WindowInspector.Close()
        catch Error as err
            this.Errors.Report(err)
        try this.Config.SaveAll()
        catch Error as err
            this.Errors.Report(err)
        this.Errors.Stop()
    }
}
