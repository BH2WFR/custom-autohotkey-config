; Anki 样式发送；Meta 对应 Windows 的 Win 键，不在此处注册热键。
class AnkiStyles {
    static Shortcuts := Map(
        "fg_rd", "{F13}",
        "fg_gn", "^{F13}",
        "fg_bl", "+{F13}",
        "fg_or", "^+{F13}",
        "fg_gy", "#+{F13}",
        "st_inv", "#{F13}",
        "cl_gy", "#^+{F13}",
        "cl_or", "#!{F13}",
        "cl_bl", "#!+{F13}",
        "cl_gn", "#^!{F13}",
        "sz_large", "#^{F13}",
        "bg_yl", "!{F13}",
        "bg_lm", "^!{F13}",
        "bg_cy", "^!+{F13}")

    static TipDuration := 600
    __New(sender, tooltip) {
        this.Sender := sender
        this.Tooltip := tooltip
    }

    Clear(*) {
        this.Sender.Send("^r")
        this.Tooltip.Show("Anki：清除格式", AnkiStyles.TipDuration)
    }

    ; Layer 分发器负责窗口匹配及修饰键释放，Blind 发送不恢复已释放的修饰键。
    Send(style, *) {
        keys := AnkiStyles.Shortcuts[style]
        if keys == ""
            return
        this.Sender.Send(keys)
        this.Tooltip.Show("Anki：" style, AnkiStyles.TipDuration)
    }
}
