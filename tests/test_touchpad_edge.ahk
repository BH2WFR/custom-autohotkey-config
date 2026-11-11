#Requires AutoHotkey v2.0
#Include ../src/lib/touchpad.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/utils/tooltip.ahk

; 独立 Edge 配置与页面接收真实手势；不阻止 contextmenu，也不发送 Esc 掩盖右键。
class EdgeTouchpadTests {
    static Edge := EnvGet("ProgramFiles(x86)") "\Microsoft\Edge\Application\msedge.exe"
    static SettleDelay := 500
    static Count := 0

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }

    static Snapshot(hwnd) {
        title := WinGetTitle(hwnd)
        if !RegExMatch(title, "\|menus=(\d+)\|scale=([\d.]+)", &match)
            throw Error("测试页尚未加载：" title)
        return {Menus: Integer(match[1]), Scale: Float(match[2])}
    }

    static Run() {
        injection := TouchInjection(), tip := TooltipPresenter()
        saved := injection.Position(), hwnd := 0
        token := A_TickCount
        profile := A_ScriptDir "\..\tmp\edge-touchpad-test-" token
        page := "file:///" StrReplace(A_ScriptDir "\fixtures\touchpad_edge.html", "\", "/") "?run=" token
        SetTitleMatchMode(2)
        try {
            Run('"' this.Edge '" --user-data-dir="' profile '" --no-first-run --no-default-browser-check'
                ' --disable-extensions --disable-background-mode --app="' page '"')
            hwnd := WinWait("TouchpadEdge-" token " ahk_exe msedge.exe",, 15)
            if !hwnd
                throw Error("Edge 测试页未打开。")
            WinActivate(hwnd)
            if !WinWaitActive(hwnd,, 3)
                throw Error("Edge 测试页未取得前台焦点。")
            Sleep(this.SettleDelay)
            bounds := WindowGeometry.Measure(hwnd)
            if !DllCall("SetPhysicalCursorPos", "Int", bounds.X + bounds.Width // 2, "Int", bounds.Y + bounds.Height // 2)
                throw OSError()
            gesture := TouchpadActions(injection, tip)
            before := this.Snapshot(hwnd)
            for direction in [TouchpadActions.ZoomIn, TouchpadActions.ZoomOut, TouchpadActions.ZoomIn, TouchpadActions.ZoomOut] {
                this.Assert(WinActive(hwnd), "Only inject into the owned Edge test window")
                this.Assert(gesture.Zoom(direction), "Native pinch completes")
                Sleep(this.SettleDelay)
                after := this.Snapshot(hwnd)
                FileAppend(Format("Pinch {1}: scale {2} -> {3}, context menus {4}`n",
                    direction, before.Scale, after.Scale, after.Menus), "*")
                this.Assert(direction * (after.Scale - before.Scale) > 0, "Edge zoom changes in requested direction")
                this.Assert(after.Menus == 0, "Pinch must not open a context menu")
                this.Assert(!gesture.Active && !gesture.Busy, "Gesture releases contacts and controller state")
                before := after
            }
        } finally {
            tip.Hide()
            injection.Restore(saved)
            if hwnd
                WinClose(hwnd)
        }
        FileAppend("PASS: " this.Count " native Edge touch assertions`n", "*", "UTF-8")
    }
}

try {
    EdgeTouchpadTests.Run()
    ExitApp(0)
} catch Error as err {
    FileAppend(err.Message "`n" err.Stack, "**", "UTF-8")
    ExitApp(1)
}
