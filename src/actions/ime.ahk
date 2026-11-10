; 按前台输入语言分流，配置和 IMM 系统接口由外部注入。
class ImeActions {
    static Hanja := "{vk19}"

    __New(settings, api, sender) {
        this.Settings := settings
        this.Api := api
        this.Sender := sender
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
        if method == ImeMethods.Api
            return this.Api.ToggleOpen(hwnd)
        this.Sender.Send(methods[method])
        return true
    }

    PrimaryMode(context) {
        switch this.Api.Language(context.Hwnd) {
            case ImeApi.Chinese:
                this.Sender.Send(ImeMethods.ChinesePunctuation[this.Settings.chinesePunctuation])
            case ImeApi.Korean:
                this.Sender.Send(ImeActions.Hanja)
            case ImeApi.Japanese:
                this.Japanese.Hiragana()
            default:
                return false
        }
        return true
    }

    SecondaryMode(context) {
        if this.Api.Language(context.Hwnd) != ImeApi.Japanese
            return false
        this.Japanese.Katakana()
        return true
    }
}
