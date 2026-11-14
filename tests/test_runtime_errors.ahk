#Requires AutoHotkey v2.0
#Include ../src/core/runtime_errors.ahk
#Include ../src/core/session.ahk
#Include ../src/utils/tooltip.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/lib/ime.ahk
#Include ../src/lib/touchpad.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/actions/middle_drag.ahk

class RuntimeErrorTests {
    static Count := 0
    static Unwound := false
    class Tip extends TooltipPresenter {
        Text := ""
        Show(text, duration) {
            this.Text := text
            super.Show(text, duration)
        }
    }
    class Sender {
        Fail := true
        Send(*) {
            if this.Fail
                throw OSError(87, "测试输入")
        }
    }
    class Injection {
        Fail := false
        FailUp := false
        Flags := []
        Restored := false
        Initialize() => 0
        Position() => {X: 500, Y: 500, Left: 0, Top: 0, Right: 1920, Bottom: 1080, Scale: 1}
        Restore(*) => this.Restored := true
        Send(points, flags) {
            this.Flags.Push(flags)
            if this.Fail || (this.FailUp && flags == TouchInjection.Up)
                throw OSError(87, "测试触点")
        }
    }
    class ClosedIme extends ImeApi {
        Control(*) => 0
    }
    class Controller {
        Called := false
        Fail := false
        SetEnabled(*) {
            this.Called := true
            if this.Fail
                throw Error("测试暂停失败")
        }
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static ExpectFailure(callback) {
        failed := false
        try callback.Call()
        catch Error
            failed := true
        this.Assert(failed, "Failure must propagate to reporting boundary")
    }
    static Run() {
        Persistent()
        this.Presenter := this.Tip()
        this.Errors := RuntimeErrors(this.Presenter)
        this.Errors.Start()
        SetTimer(ObjBindMethod(this, "Watchdog"), -10000)
        try {
            saved := ClipboardAll()
            try {
                A_Clipboard := "clipboard sentinel"
                sender := this.Sender(), clipboard := ClipboardService(sender)
                for method in ["Read", "Capture", "Paste"] {
                    this.ExpectFailure(ObjBindMethod(clipboard, method, "test"))
                    this.Assert(A_Clipboard == "clipboard sentinel", method " restores actual clipboard after sender failure")
                }
                sender.Fail := false
                result := clipboard.Capture("test")
                this.Assert(!result.Success && A_Clipboard == "clipboard sentinel", "Copy timeout preserves original clipboard")
            } finally A_Clipboard := saved

            injection := this.Injection(), touch := TouchpadActions(injection, this.Presenter)
            injection.FailUp := true
            this.ExpectFailure(ObjBindMethod(touch, "Zoom", 1))
            this.Assert(injection.Flags[-1] == TouchInjection.Cancel && !touch.Active && !touch.Busy && injection.Restored,
                "Failed touch-up still cancels contacts and restores cursor")
            touch.Frame([{X: 1, Y: 1}, {X: 2, Y: 2}], TouchInjection.Down)
            injection.Fail := true
            this.ExpectFailure(ObjBindMethod(touch, "ResetInput"))
            this.Assert(touch.Active, "Failed cancellation retains contact ownership")
            injection.Fail := false
            touch.ResetInput()
            this.Assert(!touch.Active, "Retry clears contact ownership after success")

            sender := this.Sender(), sender.Fail := false
            drag := MiddleDragController(sender, (*) => ["LControl"], (*) => false)
            drag.Begin(0)
            sender.Fail := true
            this.ExpectFailure(ObjBindMethod(drag, "Up"))
            this.Assert(drag.Owned.Length == 1, "Failed key release retains ownership")
            sender.Fail := false
            drag.ResetInput()
            this.Assert(!drag.Owned.Length, "Reset retries key release")

            first := this.Controller(), first.Fail := true, second := this.Controller()
            session := HotkeySession(this.Presenter, first, second)
            this.ExpectFailure(ObjBindMethod(session, "SetPaused", true))
            this.Assert(first.Called && second.Called && session.Paused, "Pause visits all controllers even after a failure")
            started := A_TickCount
            this.ExpectFailure(ObjBindMethod(this.ClosedIme(), "WaitUntilOpen", 1))
            this.Assert(A_TickCount - started < ImeApi.RestoreTimeout + 500, "IME restore wait is bounded")
        } catch Error as err {
            this.Fail(err)
        }
        SetTimer(ObjBindMethod(this, "ThrowFromTimer"), -10)
    }
    static ThrowFromTimer() {
        SetTimer(ObjBindMethod(this, "CheckTimer"), -100)
        ; 真实系统 API 无效句柄错误，直接走运行期 OnError。
        try ImeApi().Control(0, ImeApi.GetOpenStatus)
        finally this.Unwound := true
    }
    static CheckTimer() {
        try {
            this.Assert(this.Unwound, "OnError allows finally to unwind")
            this.Assert(InStr(this.Presenter.Text, "IME API"), "Unhandled API failure reaches Tooltip")
            hwnd := WinExist("ahk_class tooltips_class32 ahk_pid " DllCall("GetCurrentProcessId"))
            this.Assert(hwnd && InStr(ControlGetText(hwnd), "IME API"), "Native Tooltip displays actual error")
            this.Errors.Stop()
            this.Presenter.Hide()
            FileAppend("PASS " this.Count " runtime error assertions`n", "*")
            ExitApp(0)
        } catch Error as err {
            this.Fail(err)
        }
    }
    static Fail(err) {
        FileAppend("FAIL: " err.Message " at " err.Line "`n", "*")
        ExitApp(1)
    }
    static Watchdog() {
        FileAppend("FAIL: runtime error test timed out`n", "*")
        ExitApp(1)
    }
}
RuntimeErrorTests.Run()
