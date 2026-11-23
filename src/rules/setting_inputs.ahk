class SettingInputs {
    static Create(mouse, window, python, scripts) {
        return [
            {Key: "pointerFastStep", Label: "鼠标快速移动步长（像素）", Settings: mouse, Rule: InputRule.Integer(1, InputRule.SpinMax)},
            {Key: "wheelMultiplier", Label: "快速滚动倍率", Settings: mouse, Rule: InputRule.Integer(1, InputRule.SpinMax)},
            {Key: "passThroughOpacityPercent", Label: "窗口穿透不透明度（%）", Settings: window, Rule: InputRule.Integer(0, 100)},
            {Key: "condaEnvironment", Label: "Conda 环境名称", Settings: python,
                Rule: InputRule.Text("请输入环境名称，例如 base。", '^(?!\s)(?!.*\s\z)[^\\/:*?"<>|\r\n]+\z')},
            {Key: "launcherPath", Label: "PersonalScripts 启动器路径", Settings: scripts,
                Rule: InputRule.Text("输入 run-script.ps1 或 run-script.py 的完整路径，留空时从 PATH 查找。", "", ObjBindMethod(this, "IsLauncher"))}]
    }

    static IsLauncher(path) {
        if path == ""
            return true
        if !RegExMatch(path, "i)^(?:[a-z]:[\\/]|\\\\)") || RegExMatch(path, "[*?]")
            return false
        SplitPath(path, &name)
        for launcher in PersonalScripts.Launchers {
            if name = launcher {
                attributes := FileExist(path)
                return attributes != "" && !InStr(attributes, "D")
            }
        }
        return false
    }
}
