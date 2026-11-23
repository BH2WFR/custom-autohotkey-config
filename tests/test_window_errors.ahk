#Requires AutoHotkey v2.0
#Include ../src/lib/window.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/lib/window_info.ahk
#Include ../src/lib/process.ahk
#Include ../src/lib/shell.ahk
#Include ../src/rules/windows.ahk
#Include ../src/actions/window.ahk
#Include ../src/actions/window_inspector.ahk
#Include ../src/utils/tooltip.ahk

class WindowErrorTests {
    static Count := 0
    class Tip {
        Messages := []
        Show(text, duration) => this.Messages.Push(text)
    }
    class ClosingActions extends WindowActions {
        CanAdjust(hwnd) {
            result := super.CanAdjust(hwnd)
            this.Target.Destroy()
            return result
        }
    }
    class FailingActions extends WindowActions {
        _ShowDesktop() => this.Fail()
        _WheelTransparency(delta) => WindowActions.AdjustTransparency(delta, this.TargetHwnd)
        Fail() {
            throw OSError(5)
        }
    }
    class InspectorView {
        Handle := 0
        SelectedEntry := 0
        ClearTarget(*) => 0
        __New(commands) {
        }
        SetStatus(text) => this.Status := text
        Show() => 0
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static ExpectError(action, tip, message) {
        before := tip.Messages.Length
        this.Assert(action.Call() == false, message " returns failure")
        this.Assert(tip.Messages.Length == before + 1 && InStr(tip.Messages[-1], "失败："), message " emits one error tooltip")
    }
    static Run() {
        WindowGroups.Register()
        settings := {passThroughOpacityPercent: 59}
        tip := this.Tip(), actions := WindowActions(tip, settings)
        target := Gui(), closed := target.Hwnd
        target.Destroy()
        sentinel := Gui(, "Window error verification")
        sentinel.Show("NA w240 h80")
        try {
            for hwnd in [0, closed] {
                context := {Hwnd: hwnd}
                for reset in [false, true]
                    this.ExpectError(ObjBindMethod(actions, "Center", reset, context), tip, "Invalid center/reset")
                for method in ["CycleOpacity", "ToggleTopmost", "MinimizeOthers", "TogglePassThrough"]
                    this.ExpectError(ObjBindMethod(actions, method, context), tip, "Invalid " method)
                this.Assert(!actions.PassHwnd, "Invalid target is not retained as pass-through window")
                this.Assert(WinGetMinMax(sentinel.Hwnd) == 0, "Invalid minimize-others does not minimize unrelated window")
            }
            for method in ["Center", "CycleOpacity", "ToggleTopmost", "TogglePassThrough"] {
                race := this.ClosingActions(tip, settings)
                race.Target := Gui()
                race.Target.Show("NA w200 h80")
                context := {Hwnd: race.Target.Hwnd}
                action := method == "Center" ? ObjBindMethod(race, method, false, context) : ObjBindMethod(race, method, context)
                this.ExpectError(action, tip, "Window closes after validation: " method)
                this.Assert(!race.PassHwnd, "Closed target clears pending pass-through state")
            }
            actions.PassHwnd := closed
            this.ExpectError(ObjBindMethod(actions, "TogglePassThrough", {Hwnd: sentinel.Hwnd}), tip, "Closed remembered pass-through")
            this.Assert(!actions.PassHwnd, "Closed remembered handle cleared")
            actions.PassHwnd := closed
            this.ExpectError(ObjBindMethod(actions, "Stop"), tip, "Stop with invalid pass-through")
            this.Assert(!actions.PassHwnd, "Stop clears invalid handle")
            failure := this.FailingActions(tip, settings)
            failure.TargetHwnd := closed
            this.ExpectError(ObjBindMethod(failure, "WheelTransparency", -20), tip, "Wheel transparency target disappeared")
            this.ExpectError(ObjBindMethod(failure, "ShowDesktop"), tip, "System API error")

            inspector := WindowInspectorActions(this.InspectorView, actions, tip)
            before := tip.Messages.Length
            inspector.Open({Hwnd: closed})
            this.Assert(tip.Messages.Length == before + 1 && inspector.View.Status != "", "Inspector opening invalid target reports tooltip and status")
            this.ExpectError(ObjBindMethod(inspector, "Invoke", "Center"), tip, "Inspector operation without target")

            nativeTip := TooltipPresenter()
            try {
                WindowActions(nativeTip, settings).Center(false, {Hwnd: closed})
                tooltipHwnd := WinExist("ahk_class tooltips_class32 ahk_pid " ProcessExist())
                this.Assert(tooltipHwnd && InStr(ControlGetText(tooltipHwnd), "窗口居中失败"), "Real tooltip displays invalid-window error")
            } finally nativeTip.Hide()
        } finally sentinel.Destroy()
        FileAppend("PASS: " this.Count " window error assertions`n", "*", "UTF-8")
    }
}
try {
    WindowErrorTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
