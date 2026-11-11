; ASCII 使用美式键盘扫描码，其他字符走文本事件，不经过剪贴板。
class TextTyper {
    static Keys := TextTyper.BuildKeys()
    static AsciiRuns := "[\x00-\x7F]+|[^\x00-\x7F]+"
    static AsciiMax := 0x7F

    __New(sender, ime) {
        this.Sender := sender
        this.Ime := ime
    }

    static BuildKeys() {
        result := Map()
        for row in [
            {Lower: "1234567890-=", Upper: "!@#$%^&*()_+", Scan: 0x02},
            {Lower: "qwertyuiop[]", Upper: "QWERTYUIOP{}", Scan: 0x10},
            {Lower: "asdfghjkl;'", Upper: 'ASDFGHJKL:"', Scan: 0x1E},
            {Lower: "zxcvbnm,./", Upper: "ZXCVBNM<>?", Scan: 0x2C},
            {Lower: "``", Upper: "~", Scan: 0x29},
            {Lower: "\", Upper: "|", Scan: 0x2B}] {
            loop StrLen(row.Lower) {
                scan := row.Scan + A_Index - 1
                result[SubStr(row.Lower, A_Index, 1)] := {Scan: scan, Shift: false}
                result[SubStr(row.Upper, A_Index, 1)] := {Scan: scan, Shift: true}
            }
        }
        for character, scan in Map(" ", 0x39, "`t", 0x0F, "`n", 0x1C, "`b", 0x0E, Chr(27), 0x01)
            result[character] := {Scan: scan, Shift: false}
        return result
    }

    Type(text, hwnd := 0) {
        if text != ""
            this.Ime.WithClosed(hwnd ? hwnd : WinExist("A"), ObjBindMethod(this, "SendText", text), this.Sender)
    }

    SendText(text) {
        text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
        position := 1
        while RegExMatch(text, TextTyper.AsciiRuns, &match, position) {
            run := match[0]
            if Ord(run) > TextTyper.AsciiMax
                this.Sender.Text(run)
            else {
                loop parse run {
                    character := A_LoopField
                    if !TextTyper.Keys.Has(character)
                        continue
                    key := TextTyper.Keys[character]
                    shift := key.Shift
                    if RegExMatch(character, "^[A-Za-z]$") && GetKeyState("CapsLock", "T")
                        shift := !shift
                    event := Format("{sc{:03X}}", key.Scan)
                    this.Sender.Send(shift ? "{LShift down}" event "{LShift up}" : event)
                }
            }
            position := match.Pos + match.Len
        }
    }
}
