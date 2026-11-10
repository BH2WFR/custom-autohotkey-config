#Requires AutoHotkey v2.0
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/mouse.ahk
#Include ../src/lib/touchpad.ahk
#Include ../src/actions/wheel.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/rules/wheel.ahk
#Include ../src/rules/windows.ahk

class WheelTouchpadTests {
    static Count := 0
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
        sender := this.Sender(), wheel := WheelActions(MouseSender(sender), sender)
        wheel.CapsScroll(true, {Layer: 1})
        wheel.CapsScroll(false, {Layer: 2})
        this.Assert(sender.Events[1] == "chord:{WheelUp 5}" && sender.Events[2] == "chord:{WheelRight 1}", "Caps scroll temporarily strips modifiers and uses correct step sizes")
        wheel.Volume(false)
        this.Assert(sender.Events[-1] == "{Volume_Down}", "Taskbar uses system volume key")
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
        injection := this.Injection(), touchpad := TouchpadActions(injection)
        this.Assert(touchpad.Zoom(1), "Complete pinch succeeds")
        this.Assert(injection.Frames.Length == TouchpadActions.Steps + 2 && injection.Frames[1].Flags == TouchInjection.Down, "Gesture has down, update and up frames")
        this.Assert(injection.Frames[-1].Flags == TouchInjection.Up && injection.Frames[-1].Points == injection.Frames[-2].Points, "Up uses last successful update coordinates")
        this.Assert(injection.Restored && !touchpad.Active && !touchpad.Busy, "Completion restores cursor and controller state")
        packet := TouchInjection().Packet(injection.Frames[1].Points, TouchInjection.Down)
        this.Assert(packet.Size == TouchInjection.Count * TouchInjection.InfoSize, "Native touch packet has architecture-specific size")
        this.Assert(NumGet(packet, 4, "UInt") == 0 && NumGet(packet, TouchInjection.InfoSize + 4, "UInt") == 1
            && NumGet(packet, TouchInjection.FlagsOffset, "UInt") == TouchInjection.Down, "Native pointer IDs remain within initialized contact count")

        injection := this.Injection(), touchpad := TouchpadActions(injection)
        injection.FailAt := 3
        failed := false
        try touchpad.Zoom(-1)
        catch Error
            failed := true
        this.Assert(failed && injection.Frames[-1].Flags == TouchInjection.Cancel, "Update failure cancels contacts")
        this.Assert(injection.Frames[-1].Points == injection.Frames[-2].Points && injection.Restored && !touchpad.Active && !touchpad.Busy, "Failure cleanup uses last accepted coordinates and restores state")

        injection := this.Injection(), touchpad := TouchpadActions(injection)
        injection.Owner := touchpad
        injection.CancelAt := 2
        this.Assert(!touchpad.Zoom(1), "Pause interrupts active gesture")
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
