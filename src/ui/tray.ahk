; 菜单视图只接收条目、命令和状态查询，不访问 App 或配置。
class TrayView {
    __New(root, items, paused) {
        this.Root := root
        this.Paused := paused
        this.Entries := Map()
        A_TrayMenu.Delete()
        this.Build(A_TrayMenu, items)
        ; AddStandard 保留原生 Open 作为双击默认动作。
        A_TrayMenu.ClickCount := 2
        this.Refresh()
    }

    Build(targetMenu, items) {
        for item in items {
            if !IsObject(item) {
                targetMenu.Add()
                continue
            }
            if item.HasOwnProp("Standard") {
                targetMenu.AddStandard()
                continue
            }
            if item.HasOwnProp("Heading") {
                targetMenu.Add(item.Heading, (*) => 0)
                targetMenu.Disable(item.Heading)
                continue
            }
            if item.HasOwnProp("Items") {
                child := Menu()
                this.Build(child, item.Items)
                targetMenu.Add(item.Label, child)
            } else {
                this.Entries[item.Id] := {Menu: targetMenu, Item: item}
                targetMenu.Add(item.Label, ObjBindMethod(this, "Invoke", item.Id), item.HasOwnProp("Radio") ? "Radio" : "")
            }
            if item.HasOwnProp("Icon") {
                icon := RegExMatch(item.Icon, "i)^(?:[a-z]:[\\/]|\\\\)") ? item.Icon : this.Root "\res\" item.Icon
                targetMenu.SetIcon(item.Label, icon, item.HasOwnProp("IconIndex") ? item.IconIndex : 1)
            }
        }
    }

    Invoke(id, *) {
        try this.Entries[id].Item.Action.Call()
        catch as err
            MsgBox(err.Message, this.Entries[id].Item.Label, "Iconx")
        finally this.Refresh()
    }

    Refresh() {
        for entry in this.Entries {
            item := this.Entries[entry].Item
            menu := this.Entries[entry].Menu
            if item.HasOwnProp("Checked") {
                if item.Checked.Call()
                    menu.Check(item.Label)
                else
                    menu.Uncheck(item.Label)
            }
        }
        paused := this.Paused.Call()
        ; 不冻结图标，让 AHK 原生 Suspend/Pause 自动显示状态图标。
        TraySetIcon(this.Root "\res\" (paused ? "MainSuspend.ico" : "MainIcon.ico"),, false)
        A_IconTip := "Custom Autohotkey Config" (paused ? " · 已暂停" : "")
    }
}
