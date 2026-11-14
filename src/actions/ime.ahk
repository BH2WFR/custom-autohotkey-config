; 按前台输入语言分流，配置和 IMM 系统接口由外部注入。
class ImeActions {
    static Hanja := "{vk19}"
    static TipDuration := 500

    __New(settings, api, sender, tooltip) {
        this.Settings := settings
        this.Api := api
        this.Sender := sender
        this.Tooltip := tooltip
        this.Japanese := JapaneseIme(sender)
    }

    ToggleLanguage(context) {
        switch this.Api.Language(context.Hwnd) {
            case ImeApi.Chinese:
                return this.Toggle(this.Settings.chineseToggle, ImeMethods.ChineseToggle, context.Hwnd)
            case ImeApi.Korean:
                return this.Toggle(this.Settings.koreanToggle, ImeMethods.KoreanToggle, context.Hwnd)
            case ImeApi.Japanese:
                return this.Toggle(this.Settings.japaneseToggle, ImeMethods.JapaneseToggle, context.Hwnd)
            default:
                return false
        }
    }

    Toggle(method, methods, hwnd) {
        if method == ImeMethods.Api {
            if !this.Api.ToggleOpen(hwnd)
                throw Error("未找到输入法窗口或输入法未响应切换。")
            return true
        }
        this.Sender.Send(methods[method])
        return true
    }

    PrimaryMode(context) {
        switch this.Api.Language(context.Hwnd) {
            case ImeApi.Chinese:
                this.Sender.Send(ImeMethods.ChinesePunctuation[this.Settings.chinesePunctuation])
                this.Tooltip.Show("切换中英标点模式", ImeActions.TipDuration)
            case ImeApi.Korean:
                this.Sender.Send(ImeActions.Hanja)
                this.Tooltip.Show("韩文：汉字转换", ImeActions.TipDuration)
            case ImeApi.Japanese:
                this.Japanese.Hiragana()
                this.Tooltip.Show("ひらがな", ImeActions.TipDuration)
            default:
                return false
        }
        return true
    }

    SecondaryMode(context) {
        if this.Api.Language(context.Hwnd) != ImeApi.Japanese
            return false
        this.Japanese.Katakana()
        this.Tooltip.Show("カタカナ", ImeActions.TipDuration)
        return true
    }
}
