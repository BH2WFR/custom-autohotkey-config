#Requires AutoHotkey v2.0
#Include ../src/lib/json.ahk
#Include ../src/lib/python.ahk
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/ime.ahk
#Include ../src/hotkeys/layers.ahk
#Include ../src/hotkeys/registry.ahk
#Include ../src/hotkeys/dispatcher.ahk
#Include ../src/hotkeys/virtual_keyboard.ahk
#Include ../src/actions/screen_keyboard.ahk

class ScreenKeyboardTests {
    class RecordingSender {
        Events := ""
        Send(keys) => this.Events .= keys
    }
    static Policies() {
        sender := this.RecordingSender()
        input := VirtualKeyboardInput(HotkeyRegistry(), sender, (key, hwnd) => "F1", (*) => 0)
        begin := Map("command", "begin", "modifiers", [])
        stroke := Map("command", "key", "modifiers", [], "key", "b")
        end := Map("command", "end", "modifiers", [])
        input.Handle(begin, 1)
        input.Handle(stroke, 1)
        input.Handle(end, 1)
        if sender.Events != "{F1 down}{B}{F1 up}"
            throw Error("Remote layer does not bracket the key: " sender.Events)
        sender.Events := ""
        input.Handle(begin, 1)
        input.Handle(end, 1)
        if sender.Events != "{F1}"
            throw Error("Unused remote layer does not send the language key")
        sender.Events := ""
        input.Handle(begin, 1)
        input.SetEnabled(false)
        input.Handle(stroke, 1)
        if sender.Events != "" || input.Target
            throw Error("Pause did not clear virtual input")
        input.SetEnabled(true)
        input.Handle(stroke, 1)
        if sender.Events != "{B}"
            throw Error("Resume retained the previous layer")
        FileAppend("PASS: 4 virtual input policy assertions`n", "*", "UTF-8")
    }
    static Mark(value, *) => this.Sender.Text(value)
    static Layer(context) => this.Mark("[" context.Layer "]")
    static Pass(context) => this.Mark(context.Modifiers.Get("LControl", false) ? "[ctrl]" : "[pass]")
    static Run() {
        Thread("Interrupt", 0)
        InstallKeybdHook()
        root := A_ScriptDir "\.."
        this.Sender := KeyboardSender()
        registry := HotkeyRegistry()
        loop 4
            registry.Layers("2", Map(A_Index, ObjBindMethod(this, "Layer")))
        registry.Once("e", Map(1, ObjBindMethod(this, "Mark", "[once]")))
        registry.Pass("q", ObjBindMethod(this, "Pass"))
        registry.Layers("a", Map(1, ObjBindMethod(this, "Mark", "[default]")))
        registry.App("Screen keyboard native test").Layers("a", Map(1, ObjBindMethod(this, "Mark", "[app]")))
        this.Input := VirtualKeyboardInput(registry, this.Sender, (key, hwnd) => "layer", ObjBindMethod(this, "Mark", "[tap]"))
        python := PythonRuntime("base")
        this.Keyboard := ScreenKeyboard(python, root)
        this.Keyboard.Connect(this.Input)
        this.Window := Gui(, "Screen keyboard native test")
        this.Edit := this.Window.AddEdit("w700 h120")
        this.Window.Show("x80 y80")
        this.OtherWindow := Gui(, "Screen keyboard switch target")
        this.OtherEdit := this.OtherWindow.AddEdit("w300 h100")
        this.OtherWindow.Show("NA x850 y80")
        WinActivate("ahk_id " this.Window.Hwnd)
        if !WinWaitActive("ahk_id " this.Window.Hwnd,, 3)
            throw Error("Test window has no foreground focus")
        this.Edit.Focus()
        this.Result := root "\tmp\screen-keyboard-test.txt"
        if FileExist(this.Result)
            FileDelete(this.Result)
        try ImeApi().WithClosed(this.Window.Hwnd, ObjBindMethod(this, "Desktop", python, root))
        finally {
            this.Keyboard.Stop()
            this.Window.Destroy()
            this.OtherWindow.Destroy()
        }
    }

    static Desktop(python, root) {
        this.Keyboard.Pid := python.Launch(A_ScriptDir "\test_screen_keyboard.py",
            [A_ScriptHwnd, this.Edit.Hwnd, this.Result, this.OtherWindow.Hwnd,
                A_Args.Length ? A_Args[1] : "", this.OtherEdit.Hwnd], root, false)
        if ProcessWaitClose(this.Keyboard.Pid, 35)
            throw Error("Screen keyboard test timeout")
        result := FileRead(this.Result, "UTF-8")
        FileAppend(result, "*", "UTF-8")
        if !InStr(result, "PASS:")
            throw Error("Screen keyboard test failed")
    }
}

try {
    ScreenKeyboardTests.Policies()
    if A_Args.Length && A_Args[1] == "--unit"
        ExitApp(0)
    ScreenKeyboardTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message "`n" err.Stack, "**", "UTF-8")
    ExitApp(1)
}
