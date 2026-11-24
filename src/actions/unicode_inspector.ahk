; Unicode 查看器的选区输入与界面反馈。
class UnicodeInspectorActions {
    static Script := "tools\input-and-text\unicode-inspector.py"
    static Title := "Unicode 字符查看器"

    __New(scripts, clipboard) {
        this.Scripts := scripts
        this.Clipboard := clipboard
    }

    Open(context := unset) {
        try {
            if IsSet(context) {
                selection := this.Clipboard.Read(EditingPolicy.Keys(context.Hwnd).Copy)
                arguments := selection.Success ? ["--", selection.Text] : []
            } else
                arguments := ["--clip"]
            return this.Scripts.Launch(UnicodeInspectorActions.Script, arguments)
        } catch as err {
            MsgBox(err.Message, UnicodeInspectorActions.Title, "Iconx")
        }
    }
}
