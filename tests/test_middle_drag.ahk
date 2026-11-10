#Requires AutoHotkey v2.0
#Include ../src/actions/middle_drag.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/middle_drag.ahk

class MiddleDragTests {
    static Count := 0
    static Physical := Map()
    static Logical := Map()
    static Keys := []

    class FakeSender {
        __New() {
            this.Events := []
            this.FailNext := false
        }
        Send(keys) {
            this.Events.Push(keys)
            if this.FailNext {
                this.FailNext := false
                throw Error("Injected send failure")
            }
        }
    }

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static Resolve(hwnd) => this.Keys
    static Pressed(key, physicalOnly := false) => this.Physical.Has(key) || (!physicalOnly && this.Logical.Has(key))
    static Reset(keys) {
        this.Keys := keys
        this.Physical := Map()
        this.Logical := Map()
        this.Sender := this.FakeSender()
        this.Drag := MiddleDragController(this.Sender, ObjBindMethod(this, "Resolve"), ObjBindMethod(this, "Pressed"))
    }

    static Run() {
        this.Reset(MiddleDragPolicy.Left)
        this.Assert(this.Drag.CanHandle(), "Supported window captures middle down")
        this.Drag.Begin(1)
        this.Drag.Begin(1)
        this.Assert(this.Sender.Events.Length == 1 && this.Sender.Events[1] == "{LButton down}", "Left drag begins once")
        this.Keys := MiddleDragPolicy.SpaceLeft
        this.Drag.Up()
        this.Assert(this.Sender.Events[2] == "{LButton up}", "Focus change does not change release keys")
        this.Assert(!this.Drag.Held && !this.Drag.Owned.Length, "Key-up clears drag")

        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Drag.Begin(1)
        this.Assert(this.Sender.Events[1] == "{Space down}{LButton down}", "Adobe drag presses Space before left button")
        this.Drag.Up()
        this.Assert(this.Sender.Events[2] == "{LButton up}{Space up}", "Adobe drag releases left button before Space")
        this.Drag.Up()
        this.Assert(this.Sender.Events.Length == 2, "Duplicate key-up emits nothing")

        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Drag.Begin(1)
        this.Drag.SetEnabled(false)
        this.Assert(this.Sender.Events[2] == "{LButton up}{Space up}", "Pause releases simulated input")
        this.Assert(this.Drag.IsHeld() && this.Drag.CanHandle(), "Pause retains physical middle key-up capture")
        this.Drag.SetEnabled(true)
        this.Drag.Begin(1)
        this.Assert(this.Sender.Events.Length == 2, "Resume while held does not restart drag")
        this.Drag.Up()
        this.Drag.Begin(1)
        this.Assert(this.Sender.Events.Length == 3, "New press after release starts drag")
        this.Drag.Stop()
        this.Assert(this.Sender.Events[4] == "{LButton up}{Space up}" && !this.Drag.CanHandle(), "Stop releases and disables drag")

        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Physical["Space"] := true
        this.Drag.Begin(1)
        this.Drag.Up()
        this.Assert(this.Sender.Events[1] == "{LButton down}" && this.Sender.Events[2] == "{LButton up}", "Preheld Space is not released")
        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Logical["Space"] := true
        this.Physical["LButton"] := true
        this.Drag.Begin(1)
        this.Drag.Up()
        this.Assert(!this.Sender.Events.Length, "Existing logical or physical input is borrowed")
        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Drag.Begin(1)
        this.Physical["LButton"] := true
        this.Drag.Up()
        this.Assert(this.Sender.Events[2] == "{Space up}", "Physical left press during drag retains control of its release")

        this.Reset(MiddleDragPolicy.None)
        this.Assert(!this.Drag.CanHandle(), "Unmatched window retains native middle button")
        this.Drag.Begin(1)
        this.Drag.Up()
        this.Assert(!this.Sender.Events.Length, "Window match disappearing before callback emits nothing")

        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Sender.FailNext := true
        previousCritical := A_IsCritical
        failed := false
        try this.Drag.Begin(1)
        catch Error
            failed := true
        this.Assert(failed && this.Sender.Events[2] == "{LButton up}{Space up}", "Send failure releases acquired keys")
        this.Assert(!this.Drag.Owned.Length && A_IsCritical == previousCritical, "Failure restores controller and thread state")
        this.Drag.Up()
        this.Policy()
        this.Reset(MiddleDragPolicy.SpaceLeft)
        this.Drag.Begin(1)
        this.Physical["MButton"] := true
        this.Drag.ResetInput()
        this.Assert(this.Sender.Events[-1] == "{LButton up}{Space up}" && !this.Drag.Owned.Length, "Reset releases owned drag keys")
        this.Drag.Begin(1)
        this.Assert(this.Drag.Held && this.Sender.Events.Length == 2, "Reset while physically held cannot restart drag")
        this.Physical.Clear()
        this.Drag.ResetInput()
        this.Assert(!this.Drag.Held && this.Drag.Enabled, "Reset clears stale middle state without disabling controller")
        FileAppend("PASS: " this.Count " middle drag assertions" Chr(10), "*", "UTF-8")
    }

    static Policy() {
        WindowGroups.Register()
        window := Gui(, "Middle drag classification test")
        window.Show("NA w240 h80")
        try {
            this.Assert(!MiddleDragPolicy.Resolve(window.Hwnd).Length, "Ordinary windows do not map middle button")
            GroupAdd(WindowGroups.ChatImageViewer, "ahk_id " window.Hwnd)
            this.Assert(MiddleDragPolicy.Resolve(window.Hwnd) == MiddleDragPolicy.Left, "Chat image category inherits left drag")
            GroupAdd(WindowGroups.MiddleDragSpaceLeft, "ahk_id " window.Hwnd)
            this.Assert(MiddleDragPolicy.Resolve(window.Hwnd) == MiddleDragPolicy.SpaceLeft, "Adobe drag takes precedence when categories overlap")
        } finally window.Destroy()
        this.Assert(!MiddleDragPolicy.Resolve(0).Length, "No foreground window does not map middle button")
    }
}

try {
    MiddleDragTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}
