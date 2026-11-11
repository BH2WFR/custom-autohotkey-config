class PathMenuActions {
    static TipDuration := 500
    static ErrorDuration := 1200
    __New(tooltip, opener) {
        this.Tooltip := tooltip
        this.Opener := opener
    }
    Open(item, *) {
        if item.Target == ""
            return
        try {
            this.Opener.Call(item.Target, item.Folder)
            this.Tooltip.Show("打开 " item.Name, PathMenuActions.TipDuration)
        } catch as err {
            this.Tooltip.Show("无法打开 " item.Name "：" err.Message, PathMenuActions.ErrorDuration)
        }
    }
}
