; 输入规则将编辑框中的原文转换为可保存的值。谓词接收转换后的值，返回真假。
class InputRule {
    static SpinMax := 2147483647

    static Integer(minimum, maximum, choices := 0, predicate := 0, hint := "") {
        rule := this()
        rule.Minimum := minimum, rule.Maximum := maximum
        rule.Choices := choices, rule.Predicate := predicate
        rule.Hint := "允许范围：" minimum "–" maximum "（整数）"
        if choices {
            list := ""
            for value in choices
                list .= (list == "" ? "" : "、") value
            rule.Hint .= "。可选值：" list
        }
        if hint != ""
            rule.Hint .= "。" hint
        return rule
    }

    static Text(hint, pattern := "", predicate := 0, multiline := false, wrap := true) {
        rule := this()
        rule.Hint := hint, rule.Pattern := pattern, rule.Predicate := predicate
        rule.Multiline := multiline, rule.Wrap := wrap
        return rule
    }

    IsNumeric => this.HasOwnProp("Minimum")

    Parse(raw) {
        value := raw
        if this.IsNumeric {
            raw := Trim(raw)
            if !RegExMatch(raw, "^[+-]?[0-9]+\z") || StrLen(LTrim(raw, "+-0")) > 10
                throw ValueError(this.Hint)
            value := Integer(raw)
            if value < this.Minimum || value > this.Maximum || (this.Choices && !this.Choices.Has(value))
                throw ValueError(this.Hint)
        } else {
            if !this.Multiline && RegExMatch(value, "[\r\n]")
                throw ValueError("此设置只接受单行文本。")
            if this.Pattern != "" && !RegExMatch(value, this.Pattern)
                throw ValueError(this.Hint)
        }
        if this.Predicate && !this.Predicate.Call(value)
            throw ValueError(this.Hint)
        return value
    }
}
