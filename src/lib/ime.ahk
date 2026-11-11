; 从 AHK-SysUtil2 精简的 IME 基础能力，不包含项目配置或热键。
class ImeApi {
    static Chinese := 0x04
    static Korean := 0x12
    static Japanese := 0x11
    static PrimaryLanguageMask := 0x03FF
    static WmImeControl := 0x0283
    static GetOpenStatus := 0x0005
    static SetOpenStatus := 0x0006
    static AbortIfHung := 0x0002
    static MessageTimeout := 200
    static RestoreDelay := 50
    static GuiInfoSize := 8 + 6 * A_PtrSize + 16
    static FocusOffset := 8 + A_PtrSize

    Language(hwnd) {
        if !hwnd
            return 0
        thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        return thread ? DllCall("GetKeyboardLayout", "UInt", thread, "UPtr") & ImeApi.PrimaryLanguageMask : 0
    }

    Window(hwnd) {
        if !hwnd
            return 0
        thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        if !thread
            return 0
        info := Buffer(ImeApi.GuiInfoSize, 0)
        NumPut("UInt", info.Size, info)
        if !DllCall("GetGUIThreadInfo", "UInt", thread, "Ptr", info)
            return 0
        focus := NumGet(info, ImeApi.FocusOffset, "Ptr")
        return focus ? DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", focus, "Ptr") : 0
    }

    ToggleOpen(hwnd) {
        imeWindow := this.Window(hwnd)
        if !imeWindow
            return false
        opened := this.Control(imeWindow, ImeApi.GetOpenStatus)
        this.Control(imeWindow, ImeApi.SetOpenStatus, !opened)
        return !!this.Control(imeWindow, ImeApi.GetOpenStatus) == !opened
    }

    ; 扫描码打字期间关闭 IME，完成或异常后恢复原状态。
    WithClosed(hwnd, action) {
        imeWindow := this.Window(hwnd)
        if !imeWindow
            return action.Call()
        opened := this.Control(imeWindow, ImeApi.GetOpenStatus)
        try {
            if opened
                this.Control(imeWindow, ImeApi.SetOpenStatus, false)
            return action.Call()
        } finally {
            if opened {
                ; SendEvent 返回时目标窗口可能尚未处理完输入，过早恢复会让 IME 吞掉扫描码。
                Sleep(ImeApi.RestoreDelay)
                this.Control(imeWindow, ImeApi.SetOpenStatus, opened)
            }
        }
    }

    Control(hwnd, command, value := 0) {
        result := 0
        if !DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", ImeApi.WmImeControl,
            "UPtr", command, "Ptr", value, "UInt", ImeApi.AbortIfHung,
            "UInt", ImeApi.MessageTimeout, "UPtr*", &result, "Ptr")
            throw Error("IME API 调用失败或超时。")
        return result
    }
}

; 日文输入模式快捷键；输入出口由调用方注入。
class JapaneseIme {
    static CapsLockKey := "capslock"
    static KanaKey := "kana"
    static HiraganaKeys := Map(
        JapaneseIme.CapsLockKey, "^{CapsLock}", JapaneseIme.KanaKey, "{vk15}")
    static KatakanaKeys := Map(
        JapaneseIme.CapsLockKey, "!{CapsLock}", JapaneseIme.KanaKey, "+{vk15}")

    __New(sender) {
        this.Sender := sender
    }

    Hiragana(method := JapaneseIme.CapsLockKey) => this.Sender.Send(JapaneseIme.HiraganaKeys[method])
    Katakana(method := JapaneseIme.CapsLockKey) => this.Sender.Send(JapaneseIme.KatakanaKeys[method])
}
