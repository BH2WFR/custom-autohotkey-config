; 自动编辑的按键序列和选区转换，不包含应用名单或热键定义。
class TextEditor {
    __New(sender, clipboard) {
        this.Sender := sender
        this.Clipboard := clipboard
    }

    Transform(callback, copyKey, pasteKey) {
        selected := this.Clipboard.Read(copyKey)
        if !selected.Success
            return false
        this.Clipboard.Paste(callback.Call(selected.Text), pasteKey)
        return true
    }

    Indent(remove, copyKey, pasteKey) {
        selected := this.Clipboard.Read(copyKey)
        ; 旧版只对多行选区整体缩进，单行选区改为处理当前整行。
        if !selected.Success || !InStr(RTrim(selected.Text, "`r`n"), "`n")
            selected := this.Clipboard.Read(copyKey, true)
        if selected.Success || !remove
            this.Clipboard.Paste(TextTransforms.Indent(selected.Text, remove), pasteKey)
    }

    LineEnding(suffix, newLine := false) {
        this.Sender.Send("{End 2}")
        this.Sender.Text(suffix)
        if newLine
            this.Sender.Send("{Enter}")
    }

    NewLine(above) => this.Sender.Send((above ? "{Home 2}{Up}" : "") "{End 2}{Enter}")
    DeleteLine() => this.Sender.Send("{End 2}+{Home 2}{Backspace 2}")
    DeleteFirstCharacter() => this.Sender.Send("{Left}{Backspace}{Right}")
}
