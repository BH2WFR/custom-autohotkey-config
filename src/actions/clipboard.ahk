; 主/第二剪贴板的热键动作；基础读写和文本转换由 lib 执行。
class ClipboardActions {
    __New(clipboard, typer, sender) {
        this.Clipboard := clipboard
        this.Typer := typer
        this.Sender := sender
        this.Second := ""
    }

    Copy(cut, line, second, context) {
        if line && !EditingPolicy.CanEditLine(context.Hwnd)
            return
        keys := EditingPolicy.Keys(context.Hwnd)
        key := cut ? keys.Cut : keys.Copy
        if second {
            selected := this.Clipboard.Read(key, line)
            if selected.Success
                this.Second := selected.Text
        } else if line
            this.Clipboard.Capture(key, true)
        else
            this.Sender.Send(key)
        if line
            this.Sender.Send("{End 2}")
    }

    Paste(advanced, second, context) {
        keys := EditingPolicy.Keys(context.Hwnd)
        if !second && WindowGroups.Matches(WindowGroups.FileManager, context.Hwnd) {
            if !advanced
                this.Sender.Send(keys.Paste)
            return
        }
        text := second ? this.Second : A_Clipboard
        if text == ""
            return
        this.Clipboard.Paste(advanced ? TextTransforms.AdvancedPaste(text) : text, keys.Paste)
    }

    Type(second, context) => this.Typer.Type(second ? this.Second : A_Clipboard, context.Hwnd)
}
