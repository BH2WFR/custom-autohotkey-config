; 项目保留的输入法切换方式。
class ImeMethods {
    static Api := "api"
    static CtrlSpace := "ctrl_space"
    static Shift := "shift"
    static Weasel := "weasel"
    static CtrlPeriod := "ctrl_period"
    static Hangul := "hangul"
    static AltGrave := "alt_grave"
    static ChineseToggle := Map(
        ImeMethods.Api, "", ImeMethods.CtrlSpace, "^{Space}",
        ImeMethods.Shift, "{Shift}", ImeMethods.Weasel, "^{F20}")
    static ChinesePunctuation := Map(ImeMethods.CtrlPeriod, "^{.}", ImeMethods.Weasel, "^{F21}")
    static KoreanToggle := Map(ImeMethods.Api, "", ImeMethods.Hangul, "{vk15}")
    static JapaneseToggle := Map(ImeMethods.Api, "", ImeMethods.AltGrave, "!{vkC0sc029}")
}
