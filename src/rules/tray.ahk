; 项目菜单布局与命令名；命令实现由组装入口注入。
class TrayBindings {
    static SettingsIcon := A_WinDir "\ImmersiveControlPanel\SystemSettings.exe"
    static ShellIcons := A_WinDir "\System32\shell32.dll"
    static FolderIconIndex := 4
    static RefreshIconIndex := 239
    static Create(commands, checks, editors) {
        items := [
            this.Item("keyboard", "屏幕键盘", commands, checks, "Menu_OnScreenKeyboard.ico"),
            this.Item("paths", "快捷路径与系统工具", commands, checks, this.ShellIcons, this.FolderIconIndex),
            {Label: "其他工具", Items: [
                {Heading: " 以下为 PersonalScripts 工具"},
                this.Item("autoTyper", "自动打字工具", commands, checks),
                this.Item("textProcessor", "文本处理工具", commands, checks),
                this.Item("unicodeInspector", "Unicode 字符查看器", commands, checks),
                this.Item("keyboardRemapper", "键盘映射编辑器", commands, checks), "",
                this.Item("systemEventViewer", "系统事件查看器", commands, checks),
                this.Item("windowInspector", "窗口信息查看器", commands, checks), "",
                this.Item("rcloneSync", "rclone-sync", commands, checks), "",
                this.Item("imageOcr", "图片文字与公式识别", commands, checks),
                this.Item("matrixViewer", "矩阵查看器", commands, checks), "",
                this.Item("runScript", "run-script 启动器", commands, checks)]},
            "",
            this.Item("mouse", "F2 中键 / F3 向上滚动 / F4 向下滚动", commands, checks)
        ]
        remote := []
        for mode, label in Map("layer", "本地 Layer", "CapsLock", "发送 CapsLock", "F1", "发送 F1", "F24", "发送 F24") {
            item := this.Item("remote/" mode, label, commands, checks)
            item.Radio := true
            remote.Push(item)
        }
        ime := []
        for property, definition in Map(
            "chineseToggle", {Label: "中文/英文切换方式", Choices: Map(ImeMethods.Api, "API（IMM）", ImeMethods.CtrlSpace, "Ctrl+Space", ImeMethods.Shift, "Shift", ImeMethods.Weasel, "小狼毫魔改（Ctrl+F20）")},
            "chinesePunctuation", {Label: "中文标点切换方式", Choices: Map(ImeMethods.CtrlPeriod, "Ctrl+.", ImeMethods.Weasel, "小狼毫魔改（Ctrl+F21）")},
            "koreanToggle", {Label: "韩文/英文切换方式", Choices: Map(ImeMethods.Api, "API（IMM）", ImeMethods.Hangul, "韩/英键（VK_HANGUL）")},
            "japaneseToggle", {Label: "日文/英文切换方式", Choices: Map(ImeMethods.Api, "API（IMM）", ImeMethods.AltGrave, "Alt+反引号")}) {
            choices := []
            for method, label in definition.Choices {
                item := this.Item("ime/" property "/" method, label, commands, checks)
                item.Radio := true
                choices.Push(item)
            }
            ime.Push({Label: definition.Label, Items: choices})
        }
        settings := [
            {Label: "Layer 键设置", Items: [this.Item("capslock", "CapsLock 作为 Layer 键", commands, checks),
                this.Item("f1", "F1 作为 Layer 键", commands, checks),
                this.Item("f24", "F24 作为 Layer 键", commands, checks)]},
            this.Item("xbuttons", "侧键映射", commands, checks),
            this.Item("reverse", "反转横向滚动", commands, checks),
            this.Item("transparency", "Win + 滚轮调节窗口透明度", commands, checks),
            {Label: "输入法", Items: ime}, {Label: "远程桌面/虚拟机中的 Layer", Items: remote}, ""]
        for item in editors
            settings.Push(this.Item(item.Key, item.Label "…", commands, checks))
        settings.Push("", this.Item("autorun", "开机启动", commands, checks))
        items.Push({Label: "其他设置", Items: settings, Icon: this.SettingsIcon, IconIndex: 1}, "",
            this.Item("config", "打开配置目录", commands, checks, this.ShellIcons, this.FolderIconIndex),
            this.Item("readConfig", "重新读取配置", commands, checks, this.ShellIcons, this.RefreshIconIndex),
            this.Item("help", "热键说明", commands, checks, "Menu_Help.ico"), "",
            this.Item("pause", "暂停热键", commands, checks, "Menu_Suspend.ico"),
            this.Item("resetHooks", "重置钩子", commands, checks), "", {Standard: true})
        return items
    }

    static Item(id, label, commands, checks, icon := "", iconIndex := 1) {
        item := {Id: id, Label: label, Action: commands[id]}
        if checks.Has(id)
            item.Checked := checks[id]
        if icon != ""
            item.Icon := icon, item.IconIndex := iconIndex
        return item
    }
}
