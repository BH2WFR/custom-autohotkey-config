#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn VarUnset, StdOut
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/ime.ahk
#Include ../src/lib/typing.ahk
#Include ../src/lib/clipboard.ahk
#Include ../src/lib/text.ahk
#Include ../src/rules/windows.ahk
#Include ../src/rules/editing.ahk
#Include ../src/actions/clipboard.ahk

; Real Chinese IME, separate receiver process, and both clipboard actions.
class TypingImeTests {
    static Path := "D:\Projects\AHK_Scripts\custom-autohotkey-config\custom-autohotkey-config.code-workspace"
    static LongCopies := 20

    static Receiver() {
        window := Gui(, "Typing IME regression")
        window.AddEdit("w640 h240 Multi WantTab")
        window.OnEvent("Close", (*) => ExitApp())
        window.Show()
    }

    static Run() {
        Run('"' A_AhkPath '" /ErrorStdOut "' A_ScriptFullPath '" --receiver',,, &pid)
        hwnd := WinWait("Typing IME regression ahk_pid " pid,, 3)
        if !hwnd {
            ProcessClose(pid)
            throw Error("Receiver did not open")
        }
        saved := ClipboardAll()
        try {
            WinActivate(hwnd)
            if !WinWaitActive(hwnd,, 2)
                throw Error("Receiver could not take focus")
            edit := ControlGetHwnd("Edit1", hwnd)
            ControlFocus(edit)
            api := ImeApi(), sender := KeyboardSender()
            if api.Language(hwnd) != ImeApi.Chinese
                throw Error("This regression requires a Chinese IME")
            imeWindow := api.Window(hwnd)
            original := api.Control(imeWindow, ImeApi.GetOpenStatus)
            actions := ClipboardActions(0, TextTyper(sender, api), sender, 0)
            context := {Hwnd: hwnd}
            longText := ""
            loop this.LongCopies
                longText .= this.Path
            try {
                for second, text in Map(false, this.Path, true, longText) {
                    ControlSetText("", edit)
                    api.Control(imeWindow, ImeApi.SetOpenStatus, true)
                    api.WaitUntilOpen(imeWindow)
                    A_Clipboard := second ? "main clipboard sentinel" : text
                    actions.Second := second ? text : "unused second clipboard"
                    started := A_TickCount
                    actions.Type(second, context)
                    actual := ControlGetText(edit)
                    if actual != text
                        throw Error("Typing mismatch: received=" StrLen(actual) ", expected=" StrLen(text))
                    if !api.Control(imeWindow, ImeApi.GetOpenStatus)
                        throw Error("Chinese IME was not restored")
                    if A_Clipboard != (second ? "main clipboard sentinel" : text)
                        throw Error("Main clipboard changed")
                    FileAppend("PASS: second=" second ", characters=" StrLen(text) ", elapsed=" (A_TickCount - started) " ms; complete text before returning, IME restored`n", "*", "UTF-8")
                }
            } finally {
                api.Control(imeWindow, ImeApi.SetOpenStatus, original)
            }
        } finally {
            A_Clipboard := saved
            if hwnd
                WinClose(hwnd)
        }
    }
}

try {
    if A_Args.Length && A_Args[1] == "--receiver"
        TypingImeTests.Receiver()
    else {
        TypingImeTests.Run()
        ExitApp(0)
    }
} catch as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**", "UTF-8")
    ExitApp(1)
}
