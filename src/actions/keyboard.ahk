; 键盘动作及旧版状态提示；系统输入实现仍在 lib/keyboard。
class KeyboardActions {
    static TipDuration := 500
    static ReleaseDuration := 700
    __New(sender, tooltip) {
        this.Sender := sender
        this.Tooltip := tooltip
    }
    Send(keys, label, *) {
        this.Sender.Send(keys)
        this.Tooltip.Show(label, KeyboardActions.TipDuration)
    }
    Release(context) {
        context.RestoreModifiers := false
        this.Sender.Release(context.Triggers)
        this.Tooltip.Show("已释放 Ctrl Alt Shift Win 键", KeyboardActions.ReleaseDuration)
    }
    ToggleLock(key, *) {
        this.Sender.ToggleLock(key)
        this.Tooltip.Show((GetKeyState(key, "T") ? "已开启 " : "已关闭 ") key, KeyboardActions.TipDuration)
    }
}
