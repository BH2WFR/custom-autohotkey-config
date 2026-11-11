; 主/第二剪贴板的热键动作；基础读写和文本转换由 lib 执行。
class ClipboardActions {
    static TipDuration := 600
    __New(clipboard, typer, sender, tooltip) {
        this.Clipboard := clipboard
        this.Typer := typer
        this.Sender := sender
        this.Tooltip := tooltip
        this.Second := ""
    }

    Copy(cut, line, second, context) {
        if line && !EditingPolicy.CanEditLine(context.Hwnd)
            return
        keys := EditingPolicy.Keys(context.Hwnd)
        key := cut ? keys.Cut : keys.Copy
        if second {
            selected := this.Clipboard.Read(key, line)
            if !selected.Success
                return
            this.Second := selected.Text
        } else if line {
            if !this.Clipboard.Capture(key, true).Success
                return
        }
        else
            this.Sender.Send(key)
        if line
            this.Sender.Send("{End 2}")
        if second || line
            this.Tooltip.Show((second ? "第二剪贴板：" : "") (cut ? "剪切" : "复制") (line ? "当前行" : ""), ClipboardActions.TipDuration)
    }

    Paste(advanced, second, context) {
        keys := EditingPolicy.Keys(context.Hwnd)
        if !second && WindowGroups.Matches(WindowGroups.FileManager, context.Hwnd) {
            if !advanced
                this.Sender.Send(keys.Paste)
            return
        }
        text := second ? this.Second : A_Clipboard
        if text == "" {
            this.Tooltip.Show(second ? "第二剪贴板：没有内容" : "粘贴纯文本：剪贴板内容非文本", ClipboardActions.TipDuration)
            return
        }
        this.Clipboard.Paste(advanced ? TextTransforms.AdvancedPaste(text) : text, keys.Paste)
        if second
            this.Tooltip.Show("第二剪贴板：" (advanced ? "高级粘贴" : "粘贴纯文本"), ClipboardActions.TipDuration)
    }

    Type(second, context) => this.Typer.Type(second ? this.Second : A_Clipboard, context.Hwnd)
}
