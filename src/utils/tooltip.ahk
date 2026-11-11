; 使用一次性定时器自动隐藏，空闲时无轮询。
class TooltipPresenter {
    static GetFontMessage := 0x0031
    static Ellipsis := "…"

    __New() {
        this.HideCallback := ObjBindMethod(this, "Hide")
    }

    Show(text, duration := 3000) {
        SetTimer(this.HideCallback, 0)
        ToolTip(text)
        SetTimer(this.HideCallback, -duration)
    }

    ShowWithDetail(text, detail, maxWidth, duration := 3000) {
        hwnd := ToolTip(text)
        this.Show(text "`n" this.FitText(detail, maxWidth, hwnd), duration)
    }

    FitText(text, maxWidth, hwnd) {
        text := StrReplace(StrReplace(text, "`r", " "), "`n", " ")
        dc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
        font := SendMessage(TooltipPresenter.GetFontMessage, 0, 0,, "ahk_id " hwnd)
        previousFont := DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
        try {
            if this.TextWidth(dc, text) <= maxWidth
                return text
            suffix := TooltipPresenter.Ellipsis
            low := 0, high := StrLen(text)
            while low < high {
                length := (low + high + 1) // 2
                if this.TextWidth(dc, SubStr(text, 1, length) suffix) <= maxWidth
                    low := length
                else
                    high := length - 1
            }
            ; 不在 UTF-16 代理对中间截断。
            if low && Ord(SubStr(text, low, 1)) >= 0xD800 && Ord(SubStr(text, low, 1)) <= 0xDBFF
                low--
            return SubStr(text, 1, low) suffix
        } finally {
            DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", previousFont)
            DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", dc)
        }
    }

    TextWidth(dc, text) {
        size := Buffer(8)
        DllCall("gdi32\GetTextExtentPoint32W", "Ptr", dc, "Str", text, "Int", StrLen(text), "Ptr", size)
        return NumGet(size, 0, "Int")
    }

    Hide(*) {
        SetTimer(this.HideCallback, 0)
        ToolTip()
    }
}
