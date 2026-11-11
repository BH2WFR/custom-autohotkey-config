; 项目配置模型；基础库与功能对象不声明项目设置。
class AppSettings {
    static GetDirectory() => EnvGet("USERPROFILE") "\.config\custom-autohotkey-config"

    class Keyboard extends Config.IConfig {
        f1Alias := 1
        CheckValid() => this.f1Alias == 0 || this.f1Alias == 1 ? "" : "f1Alias 必须为 0 或 1。"
    }

    class Mouse extends Config.IConfig {
        xButtonMapping := 1
        reverseHorizontal := 0
        winWheelTransparency := 1
        pointerFastStep := 10
        wheelMultiplier := 5
        CheckValid() {
            for value in [this.xButtonMapping, this.reverseHorizontal, this.winWheelTransparency] {
                if value != 0 && value != 1
                    return "鼠标开关必须为 0 或 1。"
            }
            for name in ["pointerFastStep", "wheelMultiplier"] {
                value := this.%name%
                if !(value is Integer) || value < 1
                    return name " 必须为正整数。"
            }
            return ""
        }
    }

    class IME extends Config.IConfig {
        chineseToggle := ImeMethods.CtrlSpace
        chinesePunctuation := ImeMethods.CtrlPeriod
        koreanToggle := ImeMethods.Hangul
        japaneseToggle := ImeMethods.AltGrave
        CheckValid() {
            if !ImeMethods.ChineseToggle.Has(this.chineseToggle)
                return "chineseToggle 必须为 api、ctrl_space、shift 或 weasel。"
            if !ImeMethods.ChinesePunctuation.Has(this.chinesePunctuation)
                return "chinesePunctuation 必须为 ctrl_period 或 weasel。"
            if !ImeMethods.KoreanToggle.Has(this.koreanToggle)
                return "koreanToggle 必须为 api 或 hangul。"
            if !ImeMethods.JapaneseToggle.Has(this.japaneseToggle)
                return "japaneseToggle 必须为 api 或 alt_grave。"
            return ""
        }
    }

    class Python extends Config.IConfig {
        condaEnvironment := "base"
        CheckValid() => this.condaEnvironment != "" ? "" : "condaEnvironment 不能为空。"
    }

    class PersonalScripts extends Config.IConfig {
        launcherPath := ""
        CheckValid() => this.launcherPath is String ? "" : "launcherPath 必须为字符串。"
    }

    class RemoteDesktop extends Config.IConfig {
        capsMode := "F1"
        CheckValid() => RegExMatch(this.capsMode, "^(layer|CapsLock|F1|F24)$") ? "" : "capsMode 必须为 layer、CapsLock、F1 或 F24。"
    }
}
