; 文本热键适配层：选取应用策略并调用基础编辑模块。
class TextActions {
    static TipDuration := 600
    __New(editor, clipboard, sender, tooltip) {
        this.Editor := editor
        this.Clipboard := clipboard
        this.Sender := sender
        this.Tooltip := tooltip
    }
    Indent(remove, context) {
        if !EditingPolicy.CanEditLine(context.Hwnd)
            return
        keys := EditingPolicy.Keys(context.Hwnd)
        this.Editor.Indent(remove, keys.Copy, keys.Paste)
    }
    Transform(callback, context) {
        keys := EditingPolicy.Keys(context.Hwnd)
        return this.Editor.Transform(callback, keys.Copy, keys.Paste)
    }
    Wrap(context) => this.Transform((text) => TextTransforms.Wrap(text, "${", "}"), context)
    Case(upper, context) {
        if this.Transform((text) => TextTransforms.ChangeCase(text, upper), context)
            this.Tooltip.Show(upper ? "选中文本转大写" : "选中文本转小写", TextActions.TipDuration)
    }
    TitleCase(context) {
        if this.Transform(ObjBindMethod(TextTransforms, "TitleCase"), context)
            this.Tooltip.Show("已将选中文本转为: 首字母大写", TextActions.TipDuration)
    }
    LineEnding(suffix, newline, *) => this.Editor.LineEnding(suffix, newline)
    NewLine(above, *) {
        this.Editor.NewLine(above)
        this.Tooltip.Show(above ? "向上插入一行" : "向下插入一行", TextActions.TipDuration)
    }
    DeleteLine(*) => this.Editor.DeleteLine()
    DeleteFirstCharacter(*) => this.Editor.DeleteFirstCharacter()
    Accessor(get, *) {
        text := A_Clipboard
        if text == "" {
            this.Tooltip.Show("剪贴板为空，未输入函数名", TextActions.TipDuration)
            return
        }
        this.Sender.Text(TextTransforms.Accessor(text, get))
    }
    Insert(value, context) => this.Clipboard.Paste(value, EditingPolicy.Keys(context.Hwnd).Paste)
    Return(crlf, context) {
        if EditingPolicy.AltEnter(context.Hwnd) {
            this.Sender.Send("!{Enter}")
            this.Tooltip.Show("插入换行（Alt+Enter）", TextActions.TipDuration)
        } else {
            this.Insert(crlf ? "`r`n" : "`n", context)
            this.Tooltip.Show(crlf ? "输入回车换行符（CRLF）" : "输入换行符（LF）", TextActions.TipDuration)
        }
    }
}
