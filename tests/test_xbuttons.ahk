#Requires AutoHotkey v2.0
#Include ../src/rules/windows.ahk
#Include ../src/actions/xbuttons.ahk
#Include ../src/apps/xbuttons.ahk
#Include ../src/apps/caj_viewer.ahk
#Include ../src/apps/power_iso.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/lib/window_automation.ahk
#Include ../src/lib/keyboard.ahk

class XButtonTests {
    static Count := 0
    static Groups := Map()
    static Allowed := true
    static Calls := []
    static Clicks := 0

    class FakeSender {
        __New() => this.Events := []
        SendChord(keys) => this.Events.Push(keys)
    }
    class ClickAction {
        Succeeded := true
        __New() => this.Events := []
        Navigate(hwnd, back, allowed) {
            this.Events.Push([hwnd, back])
            return this.Succeeded
        }
    }
    class Tooltip {
        Messages := []
        Show(message, duration) => this.Messages.Push(message)
    }
    class ControllerActions {
        CanHandle(hwnd) => true
        Execute(*) => XButtonTests.Calls.Push("execute")
    }

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static Matches(name, hwnd) => this.Groups.Has(name)
    static IsAllowed() => this.Allowed

    static Check(groups, back, mode, expected, tip := "") {
        this.Groups := Map()
        for group in groups
            this.Groups[group] := true
        this.Sender.Events := []
        this.TooltipOutput.Messages := []
        this.Actions.Execute(1, back, mode, ObjBindMethod(this, "IsAllowed"))
        this.Assert(expected == "" ? !this.Sender.Events.Length
            : this.Sender.Events.Length == 1 && this.Sender.Events[1] == expected,
            "Navigation output: " mode " / " expected)
        if expected != ""
            this.Assert(this.TooltipOutput.Messages.Length == 1 && this.TooltipOutput.Messages[1] == tip, "Window-group-specific side-button feedback")
        else if !this.Groups.Has(WindowGroups.CajViewer) && !this.Groups.Has(WindowGroups.PowerIso)
            this.Assert(!this.TooltipOutput.Messages.Length, "Inactive or ignored side button has no feedback")
    }

    static Run() {
        this.Sender := this.FakeSender()
        this.Caj := this.ClickAction(), this.PowerIso := this.ClickAction()
        this.TooltipOutput := this.Tooltip()
        this.Actions := XButtonActions(this.Sender, this.Caj, this.PowerIso, this.TooltipOutput, ObjBindMethod(this, "Matches"))
        normal := XButtonActions.Normal, raw := XButtonActions.Raw
        this.Check([], true, normal, "!{Left}", "后退")
        this.Check([], false, normal, "!{Right}", "前进")
        this.Check([WindowGroups.NavigationAltShift], true, normal, "!+{Left}", "后退")
        this.Check([WindowGroups.NavigationNative], false, normal, "{XButton2}", "发送前进侧键")
        this.Check([WindowGroups.Anki, WindowGroups.AnkiEditor], true, normal, "!{Left}", "后退")
        this.Check([WindowGroups.Anki, WindowGroups.AnkiEditor], false, normal, "!{Right}", "前进")
        this.Check([WindowGroups.Anki], true, normal, "!{Left}", "后退")
        this.Check([WindowGroups.Anki], false, normal, "!{Right}", "前进")
        this.Check([WindowGroups.Cad], true, normal, "{Esc}", "Esc")
        this.Check([WindowGroups.Cad], false, normal, "{Enter}", "Enter")
        this.Check([WindowGroups.NavigationBackspace], true, normal, "{Backspace}", "返回上级目录")
        this.Check([WindowGroups.NavigationBackspace], false, normal, "")
        this.Check([WindowGroups.ImageViewer], true, normal, "{Left}", "上一张")
        this.Check([WindowGroups.ImageViewer], false, normal, "{Right}", "下一张")
        this.Check([WindowGroups.SiYuan], true, normal, "^{[}", "后退")
        this.Check([WindowGroups.SiYuan], false, normal, "^{]}", "前进")
        this.Check([], true, raw, "{XButton1}", "发送后退侧键")
        this.Check([WindowGroups.Cad], false, raw, "{XButton2}", "发送前进侧键")
        this.Check([WindowGroups.FolderUpAlt], true, raw, "!{Up}", "返回上级目录")
        this.Check([WindowGroups.FolderUpBackspace], false, raw, "{Backspace}", "返回上级目录")
        this.Check([], true, XButtonActions.Desktop, "^#{Left}", "切换到左侧桌面")
        this.Check([], false, XButtonActions.Desktop, "^#{Right}", "切换到右侧桌面")
        this.Check([], true, XButtonActions.Ignore, "")
        for mode in [normal, raw, XButtonActions.Desktop]
            this.Check([WindowGroups.XButtonPassthrough], true, mode, "")
        this.Allowed := false
        this.Check([], true, normal, "")
        this.Allowed := true
        this.Check([WindowGroups.CajViewer], true, normal, "")
        this.Assert(this.TooltipOutput.Messages[1] == "后退", "CAJ feedback after navigation")
        this.Check([WindowGroups.PowerIso], false, normal, "")
        this.Assert(this.TooltipOutput.Messages[1] == "前进", "PowerISO feedback after navigation")
        this.Assert(this.Caj.Events.Length == 1 && this.Caj.Events[1][2], "CAJ click direction")
        this.Assert(this.PowerIso.Events.Length == 1 && !this.PowerIso.Events[1][2], "PowerISO click direction")
        this.PowerIso.Succeeded := false
        this.Check([WindowGroups.PowerIso], false, normal, "")
        this.Assert(!this.TooltipOutput.Messages.Length, "Cancelled click sequence has no success feedback")
        this.ClickPlans()
        this.Coordinates()
        if !(A_Args.Length && A_Args[1] == "--pure")
            this.Lifecycle()
        FileAppend("PASS: " this.Count " XButton assertions" Chr(10), "*", "UTF-8")
    }

    static ClickPlans() {
        caj := CajViewerActions(false)
        pdf := caj.Plan("8.1.0", "[book.PDF] - CAJViewer", true)
        document := caj.Plan("8.1.0", "[book.caj] - CAJViewer", true)
        this.Assert(pdf[2].Y != document[2].Y && pdf[3].Y != document[3].Y, "PDF and CAJ menus use different rows")
        legacy := caj.Plan("7.3.0", "book.caj", false)
        this.Assert(legacy[2].Keys == "^{Down}", "CAJ 7 expands its menu")
        rejected := false
        try caj.Plan("9.0.0", "book.caj", true)
        catch ValueError
            rejected := true
        this.Assert(rejected, "Unknown CAJ layout is rejected before clicking")
    }

    static Coordinates() {
        for scale in [1, 1.25, 1.5, 2] {
            bounds := {X: -1920, Y: -200, Width: 1200 * scale, Height: 800 * scale, Scale: scale}
            point := WindowGeometry.ToScreen(bounds, 60, 108)
            this.Assert(point.X == -1920 + Round(60 * scale) && point.Y == -200 + Round(108 * scale), "DPI scale and negative monitor origin")
            rejected := false
            try WindowGeometry.ToScreen(bounds, 1200, 108)
            catch ValueError
                rejected := true
            this.Assert(rejected, "Scaled right edge excluded")
        }
    }

    static Lifecycle() {
        window := Gui(, "XButton lifecycle test")
        button := window.AddButton("x20 y20 w100 h40", "Click test")
        button.OnEvent("Click", (*) => this.Clicks++)
        window.Show("w300 h150")
        try {
            controller := XButtonController(this.ControllerActions(), this.Tooltip())
            this.Calls := []
            controller.Down(XButtonController.Back, XButtonActions.Normal)
            controller.Down(XButtonController.Back, XButtonActions.Normal)
            this.Assert(this.Calls.Length == 1, "Held side button runs once")
            controller.SetEnabled(false)
            this.Assert(controller.CanHandle(XButtonController.Back), "Pause preserves captured key-up")
            controller.Up(XButtonController.Back)
            this.Assert(!controller.CanHandle(XButtonController.Back), "Paused controller stops capturing after release")
            controller.SetEnabled(true)
            controller.Stop()
            this.Assert(!controller.Enabled && !controller.Held.Count, "Stop disables side buttons")

            context := DllCall("GetThreadDpiAwarenessContext", "Ptr")
            bounds := WindowGeometry.Measure(window.Hwnd)
            this.Assert(bounds.Width > 0 && bounds.Height > 0 && bounds.Scale > 0, "Real window physical bounds and monitor scale")
            this.Assert(DllCall("AreDpiAwarenessContextsEqual", "Ptr", context, "Ptr", DllCall("GetThreadDpiAwarenessContext", "Ptr")), "DPI context restored")
            this.Sender.Events := []
            automation := WindowAutomation(this.Sender)
            saved := Buffer(WindowAutomation.PointBytes)
            cursorAccessible := DllCall("GetPhysicalCursorPos", "Ptr", saved)
            this.Allowed := false
            this.Assert(!automation.Run(window.Hwnd, [{X: 20, Y: 40}], ObjBindMethod(this, "IsAllowed")), "Cancelled sequence does not click")
            this.Assert(!this.Sender.Events.Length, "Cancellation emits no input")
            this.Allowed := true
            active := !!WinActive("ahk_id " window.Hwnd)
            this.Assert(automation.Run(window.Hwnd, [{X: 20, Y: 40}], ObjBindMethod(this, "IsAllowed")) == active, "Sequence requires the captured foreground window")
            this.Assert(this.Sender.Events.Length == active, "Background window emits no click")
            current := Buffer(WindowAutomation.PointBytes)
            DllCall("GetPhysicalCursorPos", "Ptr", current)
            if cursorAccessible
                this.Assert(NumGet(saved, "Int64") == NumGet(current, "Int64"), "Physical pointer restored")
            buttonBounds := WindowGeometry.Measure(button.Hwnd)
            center := {X: (buttonBounds.X - bounds.X + buttonBounds.Width / 2) / bounds.Scale,
                Y: (buttonBounds.Y - bounds.Y + buttonBounds.Height / 2) / bounds.Scale}
            realAutomation := WindowAutomation(KeyboardSender())
            if active {
                realAutomation.Run(window.Hwnd, [center], ObjBindMethod(this, "IsAllowed"))
                Sleep(50)
                this.Assert(this.Clicks == 1, "Physical click reaches the intended control")
            } else
                FileAppend("SKIP: physical click smoke test (test window is not foreground)" Chr(10), "*", "UTF-8")
            this.Clicks := 0
            realAutomation.ClickControl(window.Hwnd, button.Hwnd)
            Sleep(50)
            this.Assert(this.Clicks == 1, "Control click reaches the intended control")
        } finally window.Destroy()
    }
}

try {
    XButtonTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}
