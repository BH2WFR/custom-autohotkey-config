#Requires AutoHotkey v2.0
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/ime.ahk
#Include ../src/lib/typing.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/lib/text.ahk
#Include ../src/lib/editing.ahk
#Include ../src/lib/mouse.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/lib/window.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/editing.ahk
#Include ../src/actions/clipboard.ahk
#Include ../src/actions/text.ahk
#Include ../src/actions/pointer.ahk
#Include ../src/actions/window.ahk
#Include ../src/utils/tooltip.ahk

class EditingTests {
    static Count := 0
    static SelectMessage := 0x00B1
    static CapsSettleDelay := 250
    class RecordingSender {
        Events := []
        TextRuns := []
        Send(keys) => this.Events.Push(keys)
        Text(value) => this.TextRuns.Push(value)
    }
    class InactiveIme {
        WithClosed(hwnd, action) => action.Call()
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static SetText(value, start := 0, end := -1) {
        this.Edit.Value := value
        this.Edit.Focus()
        SendMessage(this.SelectMessage, start, end, this.Edit.Hwnd)
    }
    static Equals(expected, message) {
        actual := StrReplace(this.Edit.Value, "`r`n", "`n")
        expected := StrReplace(expected, "`r`n", "`n")
        this.Assert(actual == expected, message " expected=" expected " actual=" actual)
    }
    static Run() {
        this.Assert(TextTransforms.Indent("a`r`nb") == "    a`r`n    b", "Multiline indent")
        this.Assert(TextTransforms.Indent("    a`n`tb", true) == "a`nb", "Space/tab unindent")
        this.Assert(TextTransforms.Unquote('"x"') == "x", "v2 final-character index")
        this.Assert(TextTransforms.TitleCase("hELLO wORLD`n中文 tEST") == "Hello World`n中文 Test", "Legacy per-word title case across lines")
        this.Assert(TextTransforms.Accessor("helloWorld", true) == "getHelloWorld", "Getter uses first character")
        this.Assert(TextTransforms.Accessor("helloWorld", false) == "setHelloWorld", "Setter uses first character")
        this.Assert(TextTransforms.AdvancedPaste('"C:\folder\file"') == "C:/folder/file", "CMake path without dialog")
        this.Assert(TextTransforms.AdvancedPaste('"C:\one"' "`r`n" '"D:\two"') == "C:/one`r`nD:/two", "Multiline paths")
        this.Assert(TextTransforms.AdvancedPaste("https://example.org/a") == "example.org", "URL domain")
        this.Assert(TextTransforms.AdvancedPaste("one`r`ntwo. `r`n中文`r`n测试") == "one two. `r`n中文测试", "Smart PDF line joining")
        this.Assert(TextTransforms.AdvancedPaste("ＡＢ１２ ﬁ") == "AB12 fi", "Width and ligature conversion")
        this.Assert(WindowTools.NextOpacity(150) == 255, "Non-step alpha becomes opaque")
        recording := this.RecordingSender()
        TextTyper(recording, this.InactiveIme()).Type("aA!`r`n中文😀")
        this.Assert(recording.Events.Length == 4 && recording.Events[4] == "{sc01C}", "ASCII produces scan codes; CRLF is one Enter")
        this.Assert(recording.TextRuns.Length == 1 && recording.TextRuns[1] == "中文😀", "Unicode including surrogate pair uses one text run")
        if A_Args.Length && A_Args[1] == "--pure" {
            FileAppend("PASS: " this.Count " pure editing assertions`n", "*", "UTF-8")
            return
        }
        saved := ClipboardAll()
        caps := GetKeyState("CapsLock", "T")
        this.Window := Gui(, "Editing verification")
        this.Tooltip := TooltipPresenter()
        this.Windows := WindowActions(this.Tooltip)
        this.Edit := this.Window.AddEdit("w600 h240 Multi WantTab")
        this.Window.Show()
        try {
            if A_Args.Length && A_Args[1] == "--windows" {
                WindowGroups.Register()
                this.WindowOperations()
                FileAppend("PASS: " this.Count " pure/window assertions`n", "*", "UTF-8")
                return
            }
            WinActivate("ahk_id " this.Window.Hwnd)
            this.Assert(WinWaitActive("ahk_id " this.Window.Hwnd,, 2), "Native test window active")
            WindowGroups.Register()
            sender := KeyboardSender(), clip := ClipboardService(sender)
            ime := ImeApi()
            editor := TextEditor(sender, clip), typer := TextTyper(sender, ime)
            text := TextActions(editor, clip, sender, this.Tooltip), actions := ClipboardActions(clip, typer, sender, this.Tooltip)
            context := {Hwnd: this.Window.Hwnd}
            if A_Args.Length && A_Args[1] == "--typing" {
                this.Typing(actions, context, ime)
                FileAppend("PASS: " this.Count " typing assertions`n", "*", "UTF-8")
                return
            }
            A_Clipboard := "clipboard sentinel"
            this.SetText("Hello")
            text.Wrap(context)
            this.Equals("${Hello}", "Wrap selection")
            this.Assert(A_Clipboard == "clipboard sentinel", "Transform restores clipboard")
            this.SetText("HeLLo")
            text.Case(false, context)
            this.Equals("hello", "Lowercase selection")
            this.SetText("hello")
            text.Case(true, context)
            this.Equals("HELLO", "Uppercase selection")
            this.SetText("a`r`nb")
            text.Indent(false, context)
            this.Equals("    a`n    b", "Native multiline indent")
            sender.Send("^a")
            text.Indent(true, context)
            this.Equals("a`nb", "Native multiline unindent")
            this.SetText("first`r`nsecond", 2, 2)
            actions.Copy(false, true, false, context)
            this.Assert(A_Clipboard == "first", "Copy current line")
            A_Clipboard := "main clipboard"
            this.SetText("second buffer")
            actions.Copy(false, false, true, context)
            this.Assert(actions.Second == "second buffer" && A_Clipboard == "main clipboard", "Second copy preserves main clipboard")
            this.SetText("")
            actions.Paste(false, true, context)
            this.Equals("second buffer", "Second clipboard paste")
            this.Assert(A_Clipboard == "main clipboard", "Second paste restores main clipboard")
            this.SetText("cut buffer")
            actions.Copy(true, false, true, context)
            this.Equals("", "Second clipboard cut")
            this.Assert(actions.Second == "cut buffer" && A_Clipboard == "main clipboard", "Second cut saves text independently")
            this.SetText("line one`r`nline two", 2, 2)
            actions.Copy(true, true, true, context)
            this.Equals("`nline two", "Second clipboard cuts current line")
            this.Assert(actions.Second == "line one" && A_Clipboard == "main clipboard", "Second line cut content")
            this.SetText("ab", 2, 2)
            text.DeleteFirstCharacter()
            this.Equals("b", "Delete first character of two-character word")
            this.SetText("first`r`nsecond", 10, 10)
            text.DeleteLine()
            this.Equals("first", "Delete line and preceding line break")
            this.SetText("abc", 1, 1)
            text.LineEnding(";", false)
            this.Equals("abc;", "Semicolon at line end")
            text.LineEnding("\", true)
            this.Equals("abc;\`n", "Backslash and new line")
            this.SetText("first`r`nsecond", 10, 10)
            text.NewLine(true)
            this.Equals("first`n`nsecond", "New line above")
            this.SetText("a", 1, 1)
            text.NewLine(false)
            this.Equals("a`n", "New line below")
            this.SetText("")
            text.Insert("`t", context)
            this.Equals("`t", "Literal tab via clipboard")
            text.Return(false, context)
            this.Equals("`t`n", "Literal LF via clipboard")
            this.SetText("")
            text.Return(true, context)
            this.Equals("`n", "Literal CRLF via clipboard")
            this.SetText("")
            sender.Text(Chr(0xA0) Chr(0x3000))
            this.Equals(Chr(0xA0) Chr(0x3000), "Nonbreaking and fullwidth spaces")
            A_Clipboard := '"C:\one\two"'
            this.SetText("")
            actions.Paste(true, false, context)
            this.Equals("C:/one/two", "Advanced paste path conversion")
            this.Assert(A_Clipboard == '"C:\one\two"', "Advanced paste restores clipboard")
            A_Clipboard := "windowTitle"
            this.SetText("")
            text.Accessor(true)
            this.Equals("getWindowTitle", "Getter typing")
            this.Typing(actions, context, ime)
            SetCapsLockState(caps)
            this.WindowOperations()
        } finally {
            this.Windows.Stop()
            this.Tooltip.Hide()
            SetCapsLockState(caps)
            A_Clipboard := saved
            this.Window.Destroy()
        }
        FileAppend("PASS: " this.Count " editing assertions`n", "*", "UTF-8")
    }

    static Typing(actions, context, ime) {
        sample := 'aAzZ09 ,.;:!?{}\"' "`t`r`n中文한글😀"
        imeWindow := ime.Window(this.Window.Hwnd)
        imeBefore := imeWindow ? ime.Control(imeWindow, ImeApi.GetOpenStatus) : false
        for locked in [false, true] {
            SetCapsLockState(locked)
            Sleep(this.CapsSettleDelay)
            for second in [false, true] {
                A_Clipboard := second ? "main clipboard sentinel" : sample
                actions.Second := second ? sample : "unused second clipboard"
                this.SetText("")
                actions.Type(second, context)
                this.Equals(sample, "Typing action sends ASCII/Unicode; CapsLock=" locked ", second=" second)
                this.Assert(A_Clipboard == (second ? "main clipboard sentinel" : sample), "Typing action preserves main clipboard")
                if imeWindow
                    this.Assert(ime.Control(imeWindow, ImeApi.GetOpenStatus) == imeBefore, "Typing action restores IME state")
            }
        }
    }

    static WindowOperations() {
        context := {Hwnd: this.Window.Hwnd}
        target := "ahk_id " context.Hwnd
        this.Windows.ToggleTopmost(context)
        this.Assert(WinGetExStyle(target) & WindowTools.TopmostStyle, "Real window becomes topmost")
        this.Windows.ToggleTopmost(context)
        this.Assert(!(WinGetExStyle(target) & WindowTools.TopmostStyle), "Repeated action removes topmost")
        for opacity in WindowTools.OpacityLevels {
            WindowTools.CycleOpacity(context.Hwnd)
            actual := WinGetTransparent(target)
            this.Assert(opacity == 255 ? actual == "" : actual == opacity, "Real window opacity cycle")
        }
        WinSetTransparent(150, target)
        WindowTools.CycleOpacity(context.Hwnd)
        this.Assert(WinGetTransparent(target) == "", "Arbitrary opacity resets to opaque")
        this.Windows.TogglePassThrough(context)
        this.Assert(WinGetExStyle(target) & WindowTools.TransparentStyle, "Window pass-through enabled")
        this.Windows.TogglePassThrough(context)
        this.Assert(!(WinGetExStyle(target) & WindowTools.TransparentStyle), "Remembered window pass-through disabled")
        this.Windows.Center(true, context)
        geometry := WindowGeometry.Measure(context.Hwnd)
        this.Assert(geometry.Width > 0 && geometry.Height > 0, "DPI-aware window reset completes")
        this.ProtectedWindows(context)
    }

    static ProtectedWindows(context) {
        target := "ahk_id " context.Hwnd
        this.Assert(!WindowGroups.Matches(WindowGroups.WindowFixed, context.Hwnd), "Ordinary GUI is not protected")
        this.Windows.TogglePassThrough(context)
        GroupAdd(WindowGroups.WindowFixed, target)
        this.Windows.TogglePassThrough(context)
        this.Assert(!this.Windows.PassHwnd && !(WinGetExStyle(target) & WindowTools.TransparentStyle),
            "Existing pass-through can still be cleared for a protected target")
        style := WinGetExStyle(target)
        alpha := WinGetTransparent(target)
        this.Windows.ToggleTopmost(context)
        this.Assert(WinGetExStyle(target) == style, "Protected window topmost remains unchanged")
        this.AssertBlockedTip()
        this.Tooltip.Hide()
        this.Windows.CycleOpacity(context)
        this.Assert(WinGetTransparent(target) == alpha, "Protected window opacity cycle is blocked")
        this.AssertBlockedTip()
        this.Tooltip.Hide()
        value := WindowActions.AdjustTransparency(-20, context.Hwnd)
        this.Assert(!IsNumber(value) && WinGetTransparent(target) == alpha, "Protected window wheel transparency is blocked")
        this.Windows.TogglePassThrough(context)
        this.Assert(!this.Windows.PassHwnd && WinGetExStyle(target) == style, "Protected window cannot enter pass-through")
        this.AssertBlockedTip()
        ; 真实系统窗口只验证分类，动作验证使用上面的独立 GUI。
        for className in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW"] {
            for hwnd in WinGetList("ahk_exe explorer.exe ahk_class " className)
                this.Assert(WindowGroups.Matches(WindowGroups.WindowFixed, hwnd), "System shell window protected: " className)
        }
    }

    static AssertBlockedTip() {
        hwnd := WinExist("ahk_class tooltips_class32 ahk_pid " DllCall("GetCurrentProcessId"))
        this.Assert(hwnd && WinGetTitle("ahk_id " hwnd) == "不可以调整这个窗口`n" this.Window.Title,
            "Blocked operation displays a native tooltip with the target title")
    }
}
try {
    EditingTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
