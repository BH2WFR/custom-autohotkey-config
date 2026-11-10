; 使用当前用户的启动目录，不写注册表。
class Autorun {
    __New(root, directory := A_Startup) {
        this.Root := root
        this.Path := directory "\Custom Autohotkey Config.lnk"
    }

    Enabled => !!FileExist(this.Path)
    IsEnabled(*) => this.Enabled
    Toggle(*) => this.SetEnabled(!this.Enabled)

    SetEnabled(enabled) {
        if enabled {
            target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
            arguments := A_IsCompiled ? "" : '"' this.Root '\main.ahk"'
            FileCreateShortcut(target, this.Path, this.Root, arguments,
                "Custom Autohotkey Config", this.Root "\res\MainIcon.ico")
        } else if this.Enabled {
            FileDelete(this.Path)
        }
    }
}
