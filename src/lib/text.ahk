; 来自旧版 String/Clipboard 的纯文本转换，不访问窗口或剪贴板。
class TextTransforms {
    static IndentMark := "    "
    static ZeroWidth := "[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}\x{206A}-\x{206F}\x{FEFF}]"
    static NarrowSpaces := "[\x{00A0}\x{2000}\x{2002}\x{2004}-\x{200A}\x{202F}\x{205F}]"
    static WideSpaces := "[\x{2001}\x{2003}\x{3000}]"
    static Cjk := "[\x{2E80}-\x{9FFF}\x{F900}-\x{FAFF}\x{FF00}-\x{FFEF}]"
    static Ligatures := Map("ﬀ", "ff", "ﬁ", "fi", "ﬂ", "fl", "ﬃ", "ffi", "ﬄ", "ffl", "ﬅ", "ft", "ﬆ", "st")

    static Indent(text, remove := false) {
        if remove
            return RegExReplace(text, "m)^( {4}|\t)", "")
        return this.IndentMark StrReplace(text, "`n", "`n" this.IndentMark)
    }

    static Wrap(text, prefix, suffix) => prefix text suffix
    static ChangeCase(text, upper) => upper ? StrUpper(text) : StrLower(text)
    static TitleCase(text) => StrTitle(text)
    static Accessor(text, get) => (get ? "get" : "set") StrUpper(SubStr(text, 1, 1)) SubStr(text, 2)

    static Unquote(text) {
        text := Trim(text)
        while StrLen(text) >= 2 && ((SubStr(text, 1, 1) == '"' && SubStr(text, -1) == '"')
            || (SubStr(text, 1, 1) == "'" && SubStr(text, -1) == "'"))
            text := SubStr(text, 2, StrLen(text) - 2)
        return text
    }

    static IsPath(text) => !!RegExMatch(text, "i)^(file:/+|[a-z]:[\\/]|\\\\)")
    static ForwardPath(text) {
        text := RegExReplace(this.Unquote(text), "i)^file:/+", "")
        return StrReplace(StrReplace(text, "\\", "/"), "\", "/")
    }

    static JoinLines(text) {
        text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
        text := StrReplace(text, Chr(2))
        lines := StrSplit(text, "`n")
        result := lines[1]
        loop lines.Length - 1 {
            previous := lines[A_Index], next := lines[A_Index + 1]
            last := SubStr(RTrim(previous, " "), -1)
            separator := last == "." || last == "。" ? "`r`n"
                : SubStr(previous, -1) == " " || RegExMatch(last, this.Cjk)
                    || RegExMatch(SubStr(next, 1, 1), this.Cjk) ? "" : " "
            result .= separator next
        }
        return result
    }

    static AdvancedPaste(text) {
        text := RegExReplace(Trim(text), this.ZeroWidth, "")
        text := RegExReplace(text, this.NarrowSpaces, " ")
        text := RegExReplace(text, this.WideSpaces, "  ")
        text := StrReplace(text, "`t", this.IndentMark)
        if !InStr(text, "`n") && !InStr(text, "`r") {
            text := this.Unquote(text)
            if RegExMatch(text, "i)^(?:https?|ftp)://([\w.\d-]+)", &url)
                text := url[1]
            else if this.IsPath(text)
                text := this.ForwardPath(text)
        } else {
            lines := StrSplit(StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n"), "`n")
            paths := true
            for line in lines
                paths := paths && this.IsPath(this.Unquote(line))
            if paths {
                text := ""
                for line in lines
                    text .= (A_Index > 1 ? "`r`n" : "") this.ForwardPath(line)
            } else
                text := this.JoinLines(text)
        }
        result := ""
        loop parse text {
            code := Ord(A_LoopField)
            result .= (code >= 0xFF10 && code <= 0xFF19) || (code >= 0xFF21 && code <= 0xFF3A)
                || (code >= 0xFF41 && code <= 0xFF5A) ? Chr(code - 0xFEE0) : A_LoopField
        }
        for ligature, replacement in this.Ligatures
            result := StrReplace(result, ligature, replacement)
        return result
    }
}
