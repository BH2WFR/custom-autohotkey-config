; 剪贴板读写与短暂借用；快捷键由调用方传入，不识别应用。
class ClipboardService {
    static CopyTimeout := 1
    static PasteDelay := 60
    static SelectLineKeys := "{End 2}+{Home 2}"
    static CopyKey := "^{Insert}"
    static CutKey := "+{Delete}"
    static PasteKey := "+{Insert}"

    __New(sender) {
        this.Sender := sender
    }

    Capture(keys, line := false) {
        saved := ClipboardAll()
        success := false
        try {
            result := this._Capture(keys, line)
            success := result.Success
            return result
        } finally {
            if !success
                A_Clipboard := saved
        }
    }

    CopySelection(keys, line := false) {
        A_Clipboard := ""
        if line
            this.Sender.Send(ClipboardService.SelectLineKeys)
        this.Sender.Send(keys)
        return ClipWait(ClipboardService.CopyTimeout)
    }

    _Capture(keys, line) {
        success := this.CopySelection(keys, line)
        return {Success: success, Text: success ? A_Clipboard : ""}
    }

    Read(keys := ClipboardService.CopyKey, line := false) {
        saved := ClipboardAll()
        try return this._Capture(keys, line)
        finally A_Clipboard := saved
    }

    Paste(text, keys := ClipboardService.PasteKey) {
        saved := ClipboardAll()
        try {
            A_Clipboard := text
            this.Sender.Send(keys)
            Sleep(ClipboardService.PasteDelay)
        } finally A_Clipboard := saved
    }
}
