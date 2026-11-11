; 应用侧键分流；窗口名单归 WindowGroups，点击布局归对应应用。
class XButtonActions {
    static Normal := "normal"
    static Raw := "raw"
    static Desktop := "desktop"
    static Ignore := "ignore"
    static DefaultKeys := ["!{Left}", "!{Right}"]
    static RawKeys := ["{XButton1}", "{XButton2}"]
    static DesktopKeys := ["^#{Left}", "^#{Right}"]
    static ParentAltUp := "!{Up}"
    static ParentBackspace := "{Backspace}"
    static TipDuration := 600
    static NavigationTips := ["后退", "前进"]
    static RawTips := ["发送后退侧键", "发送前进侧键"]
    static DesktopTips := ["切换到左侧桌面", "切换到右侧桌面"]
    static ParentTip := "返回上级目录"
    ; 按顺序匹配窗口组，发送内容和提示由同一条规则决定。
    static Rules := [
        {Group: WindowGroups.NavigationAltShift, Keys: ["!+{Left}", "!+{Right}"], Tips: ["后退", "前进"]},
        {Group: WindowGroups.NavigationNative, Keys: ["{XButton1}", "{XButton2}"], Tips: ["发送后退侧键", "发送前进侧键"]},
        {Group: WindowGroups.Cad, Keys: ["{Esc}", "{Enter}"], Tips: ["Esc", "Enter"]},
        {Group: WindowGroups.NavigationBackspace, Keys: ["{Backspace}", ""], Tips: ["返回上级目录", ""]},
        {Group: WindowGroups.ImageViewer, Keys: ["{Left}", "{Right}"], Tips: ["上一张", "下一张"]},
        {Group: WindowGroups.SiYuan, Keys: ["^{[}", "^{]}"], Tips: ["后退", "前进"]}]

    __New(sender, caj, powerIso, tooltip, matches := unset) {
        this.Sender := sender
        this.Caj := caj
        this.PowerIso := powerIso
        this.Tooltip := tooltip
        this.Matches := IsSet(matches) ? matches : ObjBindMethod(WindowGroups, "Matches")
    }

    CanHandle(hwnd) => hwnd && !this.Matches.Call(WindowGroups.XButtonPassthrough, hwnd)

    Execute(hwnd, back, mode, allowed) {
        if !allowed.Call() || !this.CanHandle(hwnd)
            return
        index := back ? 1 : 2
        switch mode {
            case XButtonActions.Ignore:
                return
            case XButtonActions.Desktop:
                return this.Send(XButtonActions.DesktopKeys[index], XButtonActions.DesktopTips[index])
            case XButtonActions.Raw:
                if this.Matches.Call(WindowGroups.FolderUpAlt, hwnd)
                    && (!this.Matches.Call(WindowGroups.Explorer, hwnd) || !this.OverTaskbar())
                    return this.Send(XButtonActions.ParentAltUp, XButtonActions.ParentTip)
                else if this.Matches.Call(WindowGroups.FolderUpBackspace, hwnd)
                    return this.Send(XButtonActions.ParentBackspace, XButtonActions.ParentTip)
                else
                    return this.Send(XButtonActions.RawKeys[index], XButtonActions.RawTips[index])
        }
        if this.Matches.Call(WindowGroups.CajViewer, hwnd)
            return this.Navigate(this.Caj, hwnd, back, allowed)
        if this.Matches.Call(WindowGroups.PowerIso, hwnd)
            return this.Navigate(this.PowerIso, hwnd, back, allowed)
        for rule in XButtonActions.Rules {
            if this.Matches.Call(rule.Group, hwnd) {
                if rule.Keys[index] != ""
                    this.Send(rule.Keys[index], rule.Tips[index])
                return
            }
        }
        this.Send(XButtonActions.DefaultKeys[index], XButtonActions.NavigationTips[index])
    }

    Send(keys, tip) {
        this.Sender.SendChord(keys)
        this.Tooltip.Show(tip, XButtonActions.TipDuration)
    }

    Navigate(action, hwnd, back, allowed) {
        if action.Navigate(hwnd, back, allowed)
            this.Tooltip.Show(XButtonActions.NavigationTips[back ? 1 : 2], XButtonActions.TipDuration)
    }

    OverTaskbar() {
        MouseGetPos(,, &hwnd)
        return this.Matches.Call(WindowGroups.Taskbar, hwnd)
    }
}
