#Requires AutoHotkey v2.0
#Include ../src/lib/keyboard.ahk
#Include ../src/hotkeys/native.ahk
#Include ../src/lib/mouse.ahk
#Include ../src/lib/touchpad.ahk
#Include ../src/actions/wheel.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/rules/wheel.ahk
#Include ../src/rules/windows.ahk

class WheelTouchpadTests {
    static Count := 0
    class Tooltip {
        Text := ""
        Show(text, duration) => this.Text := text
    }
    class Sender {
        Events := []
        Send(keys) => this.Events.Push(keys)
        SendChord(keys) => this.Events.Push("chord:" keys)
    }
    class Injection {
        Frames := []
        Restored := false
        FailAt := 0
        CancelAt := 0
        Initialize() => 0
        Position() => {X: -2, Y: 500, Left: -1920, Top: 0, Right: 0, Bottom: 1080, Scale: 1.5}
        Restore(position) => this.Restored := true
        Send(points, flags) {
            if this.FailAt && this.Frames.Length + 1 == this.FailAt {
                this.FailAt := 0
                throw Error("Injected frame failure")
            }
            this.Frames.Push({Points: points, Flags: flags})
            if this.CancelAt && this.Frames.Length == this.CancelAt
                SetTimer(ObjBindMethod(this.Owner, "SetEnabled", false), -1)
        }
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static Run() {
        settings := {wheelMultiplier: 5}
        sender := this.Sender(), wheel := WheelActions(MouseSender(sender), sender, this.Tooltip(), settings)
        wheel.CapsScroll(true, {Layer: 1, WheelSteps: 1})
        wheel.CapsScroll(false, {Layer: 2, WheelSteps: 2})
        this.Assert(sender.Events[1] == "chord:{WheelUp 5}" && sender.Events[2] == "chord:{WheelRight 2}", "Caps scroll temporarily strips modifiers and uses correct step sizes")
        settings.wheelMultiplier := 8
        wheel.CapsScroll(false, {Layer: 1, WheelSteps: 2})
        this.Assert(sender.Events[-1] == "chord:{WheelDown 16}", "Caps wheel scales by notch count and the current multiplier")
        wheel.Volume(false, 2)
        this.Assert(sender.Events[-1] == "{Volume_Down 2}", "Taskbar sends one system volume key per notch")
        acc := WheelAccumulator()
        for amount in [30, 120, 240]
            this.Assert(acc.Take("WheelUp", amount, "volume", 1) == 1, "Default mode treats each wheel message as one action")
        acc.SetEnabled(true)
        this.Assert(!acc.Take("WheelUp", 60, "volume", 1) && acc.Take("WheelDown", 120, "volume", 1) == 1
            && acc.Take("WheelDown", 240, "volume", 1) == 2 && acc.Take("WheelUp", 60, "volume", 1) == 1,
            "Whole reverse notches act immediately and preserve unfinished fine movement")
        this.Assert(!acc.Take("WheelDown", 100, "volume", 1), "Partial delta pending before toggle")
        acc.SetEnabled(false)
        this.Assert(acc.Take("WheelDown", 20, "volume", 1) == 1, "Disabling adaptation takes effect immediately")
        acc.SetEnabled(true)
        this.Assert(!acc.Take("WheelDown", 20, "volume", 1), "Re-enabling starts with no remainder")
        this.Assert(!acc.Take("WheelUp", 90, "window", 1) && !acc.Take("WheelDown", 90, "window", 1), "Opposite partial movements cancel")
        this.Assert(acc.Take("WheelDown", 270, "window", 1) == 2 && acc.Take("WheelDown", 90, "window", 1) == 1, "Negative multi-notch packets preserve their remainder")
        this.Assert(!acc.Take("WheelUp", 119, "window", 1) && !acc.Take("WheelUp", 1, "window", 2), "Different target windows do not share a remainder")
        this.Assert(!acc.Take("WheelUp", 119, "volume", 2), "Switching actions discards the previous remainder")
        this.Assert(!acc.Take("WheelRight", 119, "reverse", 2) && acc.Take("WheelUp", 1, "volume", 2) == 1
            && acc.Take("WheelRight", 1, "reverse", 2) == 1, "Diagonal scroll accumulates each axis independently")
        for enabled in [false, true] {
            acc.SetEnabled(enabled)
            for key in ["WheelUp", "WheelDown"] {
                up := key == "WheelUp"
                before := sender.Events.Length
                A_EventInfo := 120
                acc.Dispatch(key, WheelPolicy.Volume, ObjBindMethod(wheel, "Volume", up))
                this.Assert(sender.Events.Length == before + 1 && sender.Events[-1] == (up ? "{Volume_Up 1}" : "{Volume_Down 1}"),
                    "A standard detent sends exactly one volume key in either mode")
            }
        }
        this.Assert(WheelPolicy.Resolve(true, true, Map("LWin", true), true) == WheelPolicy.Caps, "Caps takes precedence over Win and taskbar")
        this.Assert(WheelPolicy.Resolve(false, true, Map("RWin", true), true) == WheelPolicy.Window, "Win takes precedence over taskbar")
        this.Assert(WheelPolicy.Resolve(false, false, Map("LWin", true), true) == WheelPolicy.Native, "Disabled Win transparency retains native input")
        this.Assert(WheelPolicy.Resolve(false, true, Map(), true) == WheelPolicy.Volume, "Unmodified taskbar wheel changes volume")
        for key in ["LControl", "RShift", "LAlt"]
            this.Assert(WheelPolicy.Resolve(false, true, Map(key, true), true) == WheelPolicy.Native, "Other modifiers pass through taskbar: " key)
        this.Assert(WheelPolicy.Resolve(false, true, Map(), false) == WheelPolicy.Native, "Ordinary wheel remains native")

        for scale in [1, 1.5, 2] {
            position := this.Injection().Position()
            position.Scale := scale
            for direction in [TouchpadActions.ZoomIn, TouchpadActions.ZoomOut] {
                plan := TouchpadActions.Plan(position, direction)
                first := plan[1][2].X - plan[1][1].X
                last := plan[-1][2].X - plan[-1][1].X
                this.Assert(direction == 1 ? last > first : last < first, "Pinch distance changes in requested direction")
                this.Assert(Abs(last - first) == Round(TouchpadActions.DistanceChange * scale), "Gesture distance scales with target monitor")
                for frame in plan {
                    for point in frame
                        this.Assert(point.X >= position.Left && point.X < position.Right && point.Y >= position.Top && point.Y < position.Bottom, "Touch contact stays on negative-coordinate monitor")
                }
            }
        }
        tip := this.Tooltip(), injection := this.Injection(), touchpad := TouchpadActions(injection, tip)
        this.Assert(touchpad.Zoom(1), "Complete pinch succeeds")
        this.Assert(tip.Text == "模拟触控板放大", "Successful zoom shows directional feedback")
        this.Assert(injection.Frames.Length == TouchpadActions.Steps + 2 && injection.Frames[1].Flags == TouchInjection.Down, "Gesture has down, update and up frames")
        this.Assert(injection.Frames[-1].Flags == TouchInjection.Up && injection.Frames[-1].Points == injection.Frames[-2].Points, "Up uses last successful update coordinates")
        this.Assert(injection.Restored && !touchpad.Active && !touchpad.Busy, "Completion restores cursor and controller state")
        packet := TouchInjection().Packet(injection.Frames[1].Points, TouchInjection.Down)
        this.Assert(packet.Size == TouchInjection.Count * TouchInjection.InfoSize, "Native touch packet has architecture-specific size")
        this.Assert(NumGet(packet, 4, "UInt") == 0 && NumGet(packet, TouchInjection.InfoSize + 4, "UInt") == 1
            && NumGet(packet, TouchInjection.FlagsOffset, "UInt") == TouchInjection.Down, "Native pointer IDs remain within initialized contact count")
        for index, point in injection.Frames[1].Points {
            offset := (index - 1) * TouchInjection.InfoSize
            this.Assert(NumGet(packet, offset + TouchInjection.TouchMaskOffset, "UInt") & TouchInjection.ContactAreaMask,
                "Each contact explicitly supplies its area")
            left := NumGet(packet, offset + TouchInjection.ContactOffset, "Int")
            top := NumGet(packet, offset + TouchInjection.ContactOffset + 4, "Int")
            right := NumGet(packet, offset + TouchInjection.ContactOffset + 8, "Int")
            bottom := NumGet(packet, offset + TouchInjection.ContactOffset + 12, "Int")
            this.Assert(left < point.X && point.X < right && top < point.Y && point.Y < bottom,
                "Nonzero contact rectangle surrounds its physical pointer position")
        }

        tip := this.Tooltip(), injection := this.Injection(), touchpad := TouchpadActions(injection, tip)
        injection.FailAt := 3
        failed := false
        try touchpad.Zoom(-1)
        catch Error
            failed := true
        this.Assert(failed && injection.Frames[-1].Flags == TouchInjection.Cancel, "Update failure cancels contacts")
        this.Assert(tip.Text == "", "Failed gesture does not show success feedback")
        this.Assert(injection.Frames[-1].Points == injection.Frames[-2].Points && injection.Restored && !touchpad.Active && !touchpad.Busy, "Failure cleanup uses last accepted coordinates and restores state")

        tip := this.Tooltip(), injection := this.Injection(), touchpad := TouchpadActions(injection, tip)
        injection.Owner := touchpad
        injection.CancelAt := 2
        this.Assert(!touchpad.Zoom(1), "Pause interrupts active gesture")
        this.Assert(tip.Text == "", "Cancelled gesture does not show success feedback")
        this.Assert(!touchpad.Enabled && !touchpad.Active && injection.Frames[-1].Flags == TouchInjection.Cancel && injection.Restored, "Pause releases contacts and restores cursor")
        FileAppend("PASS: " this.Count " wheel/touchpad assertions`n", "*", "UTF-8")
    }
}

try {
    WheelTouchpadTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
