#Requires AutoHotkey v2.0
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/ime.ahk
#Include ../src/lib/touchpad.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/utils/tooltip.ahk
#Include ../src/rules/windows.ahk

; 使用独立窗口接收真实键盘/触摸输入；需要交互桌面。
class NativeInputTests {
    static TouchMessage := 0x0240
    static TouchDown := 0x0002
    static TouchUp := 0x0004
    static TouchInfoSize := A_PtrSize == 8 ? 48 : 40
    static TouchIdOffset := 8 + A_PtrSize
    static TouchFlagsOffset := 12 + A_PtrSize
    static Points := []
    static Count := 0

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }

    static Now() {
        DllCall("QueryPerformanceCounter", "Int64*", &count := 0)
        DllCall("QueryPerformanceFrequency", "Int64*", &frequency := 0)
        return count * 1000 / frequency
    }

    static Touch(wParam, handle, *) {
        count := wParam & 0xFFFF
        info := Buffer(count * this.TouchInfoSize)
        try {
            if !DllCall("GetTouchInputInfo", "Ptr", handle, "UInt", count, "Ptr", info, "Int", this.TouchInfoSize)
                throw OSError()
            loop count {
                offset := (A_Index - 1) * this.TouchInfoSize
                this.Points.Push({X: NumGet(info, offset, "Int") / 100,
                    Id: NumGet(info, offset + this.TouchIdOffset, "UInt"),
                    Flags: NumGet(info, offset + this.TouchFlagsOffset, "UInt")})
            }
        } finally DllCall("CloseTouchInputHandle", "Ptr", handle)
        return 0
    }

    static Run() {
        Thread("Interrupt", 0)
        DllCall("SetThreadDpiAwarenessContext", "Ptr", TouchInjection.PerMonitorV2, "Ptr")
        window := Gui(, "Native input verification")
        window.AddEdit("w600 h180")
        window.Show("w640 h320")
        touch := TouchInjection(), tip := TooltipPresenter()
        saved := false
        try {
            WinActivate("ahk_id " window.Hwnd)
            if !WinWaitActive("ahk_id " window.Hwnd,, 2)
                throw Error("没有可用的交互前台窗口，未执行真实输入验证。")
            saved := touch.Position()
            WinGetPos(&x, &y, &w, &h, "ahk_id " window.Hwnd)
            if !DllCall("SetPhysicalCursorPos", "Int", x + w // 2, "Int", y + h - 45)
                throw OSError()
            this.Assert(DllCall("RegisterTouchWindow", "Ptr", window.Hwnd, "UInt", 0), "Test window accepts touch input")
            OnMessage(this.TouchMessage, ObjBindMethod(this, "Touch"))
            gesture := TouchpadActions(touch, tip)
            for direction in [TouchpadActions.ZoomIn, TouchpadActions.ZoomOut] {
                this.Points := []
                this.Assert(gesture.Zoom(direction), "Native pinch completes")
                Sleep(100)
                starts := Map(), ends := Map()
                for point in this.Points {
                    if point.Flags & this.TouchDown
                        starts[point.Id] := point.X
                    if point.Flags & this.TouchUp
                        ends[point.Id] := point.X
                }
                this.Assert(starts.Count == 2 && ends.Count == 2, "Window received two down and two up contacts")
                startValues := [], endValues := []
                for id, value in starts {
                    startValues.Push(value)
                    endValues.Push(ends[id])
                }
                change := Abs(endValues[2] - endValues[1]) - Abs(startValues[2] - startValues[1])
                this.Assert(direction * change > 0, "Window received requested pinch direction")
                this.Assert(Abs(Abs(change) - TouchpadActions.DistanceChange * touch.Position().Scale) <= 1,
                    "Window receives reduced, DPI-scaled pinch distance")
                FileAppend("Pinch " direction ": received span change " change " px`n", "*", "UTF-8")
            }

            if A_Args.Length && A_Args[1] == "--touch-only" {
                FileAppend("PASS: " this.Count " native touch assertions`n", "*", "UTF-8")
                return
            }

            WindowGroups.Register()
            sender := KeyboardSender(), ime := ImeApi()
            loop 3 {
                start := this.Now()
                KeyboardSender.ReadModifiers()
                read := this.Now()
                WindowGroups.Matches(WindowGroups.RemoteDesktop, window.Hwnd)
                matched := this.Now()
                Critical("On")
                sender.Release(["F6"])
                Critical("Off")
                released := this.Now()
                ime.Language(window.Hwnd)
                language := this.Now()
                sender.Send("^{Space}")
                sent := this.Now()
                FileAppend(Format("read={:.2f} match={:.2f} release={:.2f} language={:.2f} chord={:.2f} ms`n",
                    read-start, matched-read, released-matched, language-released, sent-language), "*", "UTF-8")
            }
            try {
                sender.Send("{RControl down}")
                Sleep(20)
                this.Assert(GetKeyState("RControl"), "Control is logically down before cleanup")
                sender.Release([])
                Sleep(20)
                this.Assert(!GetKeyState("RControl"), "Cleanup still releases a held modifier")
            } finally sender.Send("{RControl up}")
        } finally {
            tip.Hide()
            if IsObject(saved)
                touch.Restore(saved)
            window.Destroy()
        }
        FileAppend("PASS: " this.Count " native input assertions`n", "*", "UTF-8")
    }
}

try {
    NativeInputTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
