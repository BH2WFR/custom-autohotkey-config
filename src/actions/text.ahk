; 文本热键适配层：选取应用策略并调用基础编辑模块。
class TextActions {
    __New(editor, clipboard, sender) {
        this.Editor := editor
        this.Clipboard := clipboard
        this.Sender := sender
    }
    Indent(remove, context) {
        if !EditingPolicy.CanEditLine(context.Hwnd)
            return
        keys := EditingPolicy.Keys(context.Hwnd)
        this.Editor.Indent(remove, keys.Copy, keys.Paste)
    }
    Transform(callback, context) {
        keys := EditingPolicy.Keys(context.Hwnd)
        this.Editor.Transform(callback, keys.Copy, keys.Paste)
    }
    Wrap(context) => this.Transform((text) => TextTransforms.Wrap(text, "${", "}"), context)
    Case(upper, context) => this.Transform((text) => TextTransforms.ChangeCase(text, upper), context)
    LineEnding(suffix, newline, *) => this.Editor.LineEnding(suffix, newline)
    NewLine(above, *) => this.Editor.NewLine(above)
    DeleteLine(*) => this.Editor.DeleteLine()
    DeleteFirstCharacter(*) => this.Editor.DeleteFirstCharacter()
    Accessor(get, *) => this.Sender.Text(TextTransforms.Accessor(A_Clipboard, get))
    Insert(value, context) => this.Clipboard.Paste(value, EditingPolicy.Keys(context.Hwnd).Paste)
    Return(crlf, context) {
        if EditingPolicy.AltEnter(context.Hwnd)
            this.Sender.Send("!{Enter}")
        else
            this.Insert(crlf ? "`r`n" : "`n", context)
    }
}
