class ApplicationActions {
    static OpenPath(path, *) => Run('"' path '"')

    static OfferPersonalScriptsInstall(reason, url) {
        message := reason "`n`n请从以下 GitHub 页面下载并安装或更新 PersonalScripts：`n" url
            . "`n`n已安装可在「其他设置 → PersonalScripts 启动器路径」指定入口。`n现在打开项目页面吗？"
        if MsgBox(message, "PersonalScripts", "YesNo Icon! Default2") == "Yes"
            this.OpenPath(url)
    }
}
