; 原生弹出菜单，只接收声明和命令。
class PopupMenuView {
    __New(items, invoke) {
        this.Menu := this.Build(items, invoke)
    }
    Build(items, invoke) {
        targetMenu := Menu()
        for item in items {
            if !IsObject(item) {
                targetMenu.Add()
                continue
            }
            if item.HasOwnProp("Items")
                targetMenu.Add(item.Label, this.Build(item.Items, invoke))
            else {
                targetMenu.Add(item.Label, invoke.Bind(item))
                if item.HasOwnProp("Disabled") && item.Disabled
                    targetMenu.Disable(item.Label)
            }
            if item.HasOwnProp("Icon") {
                ; 系统图标资源随 Windows 版本变化，缺失图标不影响菜单命令。
                try targetMenu.SetIcon(item.Label, item.Icon, item.IconIndex)
            } else if item.HasOwnProp("ShellIcon") {
                icon := ShellTools.Icon(item.ShellIcon)
                if icon {
                    try targetMenu.SetIcon(item.Label, "HICON:*" icon)
                    finally DllCall("DestroyIcon", "Ptr", icon)
                }
            }
        }
        return targetMenu
    }
    Show(*) {
        ; Menu.Show 自行处理前台窗口与焦点恢复。
        this.Menu.Show()
    }
}
