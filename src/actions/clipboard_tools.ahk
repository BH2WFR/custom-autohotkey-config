; 热键先复制选区，托盘按工具选择是否读取现有剪贴板。
class ClipboardToolActions {
    static UnicodeInspector := {Script: "tools\input-and-text\unicode-inspector.py", Title: "Unicode Inspector", ClipboardOnTray: true}
    static TextProcessor := {Script: "tools\input-and-text\text-path-processor.py", Title: "Text and Path Processor", ClipboardOnTray: false}

    __New(scripts, clipboard) {
        this.Scripts := scripts
        this.Clipboard := clipboard
    }

    Open(tool, context := unset) {
        try {
            if IsSet(context)
                this.Clipboard.CopySelection(EditingPolicy.Keys(context.Hwnd).Copy)
            arguments := IsSet(context) || tool.ClipboardOnTray ? ["--clip"] : []
            return this.Scripts.LaunchWindow(tool.Script, tool.Title, arguments)
        } catch as err {
            MsgBox(err.Message, tool.Title, "Iconx")
        }
    }
}
