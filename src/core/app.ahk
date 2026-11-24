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
        this.WindowSettings := this.Config.Register(AppSettings.Window(), "Window")
        this.PythonSettings := this.Config.Register(AppSettings.Python(), "Python")
        this.PersonalScriptsSettings := this.Config.Register(AppSettings.PersonalScripts(), "PersonalScripts")
        this.RemoteSettings := this.Config.Register(AppSettings.RemoteDesktop(), "RemoteDesktop")
        this.ImeSettings := this.Config.Register(AppSettings.IME(), "IME")
        this.Config.LoadAll()
        this.Python := PythonRuntime(this.PythonSettings.condaEnvironment)
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
        this.PersonalTools := PersonalScripts(this.Python, this.PersonalScriptsSettings, ObjBindMethod(this.Config, "SaveAll"),
            ObjBindMethod(ApplicationActions, "OfferPersonalScriptsInstall"))
        this.UnicodeInspector := UnicodeInspectorActions(this.PersonalTools, this.Clipboard)
        this.OpenScreenKeyboard := ObjBindMethod(this, "LaunchScreenKeyboard")
        this.Typer := TextTyper(this.Sender, this.ImeApi)
        this.Editor := TextEditor(this.Sender, this.Clipboard)
        this.ClipboardActions := ClipboardActions(this.Clipboard, this.Typer, this.Sender, this.Tooltip)
        this.TextActions := TextActions(this.Editor, this.Clipboard, this.Sender, this.Tooltip)
        this.Pointer := PointerActions(this.MouseSender, this.MouseSettings)
        this.WindowInspector := WindowInspectorLauncher(root, this.Tooltip, this.WindowSettings)
        this.Windows := WindowActions(this.Tooltip, this.WindowSettings, ObjBindMethod(this.WindowInspector, "NotifyStyleChanged"))
        this.Keys := KeyboardActions(this.Sender, this.Tooltip)
        this.PathActions := PathMenuActions(this.Tooltip, ObjBindMethod(ShellTools, "Open"))
        this.Wheel := WheelActions(this.MouseSender, this.Sender, this.Tooltip, this.MouseSettings)
        this.Touchpad := TouchpadActions(TouchInjection(), this.Tooltip)
        this.Dispatcher := HotkeyDispatcher(this.State, this.Registry, this.Sender)
        WindowGroups.Register()
        this.CapsPolicy := CapsPolicy(this.RemoteSettings)
        this.Triggers := TriggerRouter(this.State, this.Sender, ObjBindMethod(this.CapsPolicy, "Resolve"))
        this.Input := HotkeyInput(this.State, this.Registry, this.Dispatcher, this.Triggers,
            CapsPolicy.Aliases(this.Settings), ObjBindMethod(this.Ime, "ToggleLanguage"))
        this.Paths := PopupMenuView(PathMenuBindings.Create(root), ObjBindMethod(this.PathActions, "Open"))
        HotkeyBindings.Register(this.Registry, this.Diagnostics, this.Ime, this.OpenScreenKeyboard, this.Anki, this.Touchpad, this.Wheel,
            this.Sender, this.ClipboardActions, this.TextActions, this.MouseSender, this.Pointer, this.Windows, this.Keys, this.Paths, this.UnicodeInspector, this.WindowInspector)
        this.Input.Start()
        this.Mouse := MouseController(this.MouseSettings, this.MouseSender)
        this.WindowAutomation := WindowAutomation(this.Sender)
        this.XButtonActions := XButtonActions(this.Sender, CajViewerActions(this.WindowAutomation), PowerIsoActions(this.WindowAutomation), this.Tooltip)
        this.XButtons := XButtonController(this.XButtonActions, this.Tooltip, this.MouseSettings.xButtonMapping)
        this.MiddleDrag := MiddleDragController(this.Sender, ObjBindMethod(MiddleDragPolicy, "Resolve"))
        this.MouseNative := NativeHotkeys()
        MouseBindings.Register(this.MouseNative, this.Mouse, this.XButtons, this.MiddleDrag, this.Input, this.Wheel, this.Windows)
        this.Session := HotkeySession(this.Tooltip, this.Input, this.Mouse, this.XButtons, this.MiddleDrag, this.Touchpad)
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
            "keyboard", this.OpenScreenKeyboard,
            "paths", ObjBindMethod(this.Paths, "Show"),
            "windowInspector", ObjBindMethod(this.WindowInspector, "Open"),
            "unicodeInspector", ObjBindMethod(this.UnicodeInspector, "Open"),
            "autoTyper", ObjBindMethod(this.PersonalTools, "Launch", "tools\input-and-text\auto-typer.py"),
            "textProcessor", ObjBindMethod(this.PersonalTools, "Launch", "tools\input-and-text\text-processor.py"),
            "keyboardRemapper", ObjBindMethod(this.PersonalTools, "Launch", "tools\windows\keyboard-remapper.py"),
            "systemEventViewer", ObjBindMethod(this.PersonalTools, "Launch", "tools\others\system-event-viewer.py"),
            "imageOcr", ObjBindMethod(this.PersonalTools, "Launch", "tools\document-processing\image-to-text-and-formula.py"),
            "matrixViewer", ObjBindMethod(this.PersonalTools, "Launch", "tools\research\matrix-viewer.py"),
            "rcloneSync", ObjBindMethod(this.PersonalTools, "LaunchConsole", "tools\network\rclone-sync.py"),
            "runScript", ObjBindMethod(this.PersonalTools, "LaunchConsole", "run-script.py"),
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
            "mouse", ObjBindMethod(this.Mouse, "FunctionKeysEnabled"),
            "xbuttons", ObjBindMethod(SettingsActions, "Read", this.MouseSettings, "xButtonMapping"),
            "reverse", ObjBindMethod(SettingsActions, "Read", this.MouseSettings, "reverseHorizontal"),
            "transparency", ObjBindMethod(SettingsActions, "Read", this.MouseSettings, "winWheelTransparency"),
            "autorun", ObjBindMethod(this.Autorun, "IsEnabled"),
            "pause", ObjBindMethod(this.Session, "IsPaused"))
        for key, property in CapsPolicy.ConfigurableAliases {
            id := StrLower(key)
            commands[id] := ObjBindMethod(this.SettingActions, "Toggle", this.Settings, property, ObjBindMethod(this, "ApplyLayerKeys"))
            checks[id] := ObjBindMethod(SettingsActions, "Read", this.Settings, property)
        }
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
        editors := SettingInputs.Create(this.MouseSettings, this.WindowSettings, this.PythonSettings, this.PersonalScriptsSettings)
        apply := Map("condaEnvironment", ObjBindMethod(this.Python, "SetEnvironment"),
            "passThroughOpacityPercent", (*) => this.WindowInspector.SyncSettings())
        for item in editors {
            dialog := SettingsInputDialog(item.Label, item.Rule)
            commands[item.Key] := ObjBindMethod(this.SettingActions, "Edit", dialog, item.Settings, item.Key, apply.Get(item.Key, 0))
        }
        this.Tray := TrayView(this.Root, TrayBindings.Create(commands, checks, editors), checks["pause"])
    }

    static LaunchScreenKeyboard(*) {
        arguments := []
        for key in ["F24", "CapsLock", "F1"] {
            property := CapsPolicy.ConfigurableAliases[key]
            if this.Settings.%property% {
                arguments.Push("--force-layer=" key)
                break
            }
        }
        return this.PersonalTools.Launch("tools\input-and-text\screen-keyboard.py", arguments)
    }

    static ApplyLayerKeys(*) {
        for key, enabled in CapsPolicy.Aliases(this.Settings)
            this.Input.SetAliasEnabled(key, enabled)
    }

    static ApplySettings() {
        this.WindowInspector.SyncSettings()
        this.ApplyLayerKeys()
        this.XButtons.SetMappingEnabled(this.MouseSettings.xButtonMapping)
        if this.Python.Environment != this.PythonSettings.condaEnvironment
            this.Python.SetEnvironment(this.PythonSettings.condaEnvironment)
    }

    static Stop(*) {
        this.Tooltip.Hide()
        for controller in [this.Input, this.Mouse, this.XButtons, this.MiddleDrag,
            this.Touchpad, this.MouseNative, this.Windows] {
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
