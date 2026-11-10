; 应用侧键分流；窗口名单归 WindowGroups，点击布局归对应应用。
class XButtonActions {
    static Normal := "normal"
    static Raw := "raw"
    static Desktop := "desktop"
    static Ignore := "ignore"
    static DefaultKeys := ["!{Left}", "!{Right}"]
    static RawKeys := ["{XButton1}", "{XButton2}"]
    static DesktopKeys := ["^#{Left}", "^#{Right}"]
    static AltShiftKeys := ["!+{Left}", "!+{Right}"]
    static AnkiEditorKeys := ["^r", "{F13}"]
    static AnkiKeys := ["^+d", "e"]
    static CadKeys := ["{Esc}", "{Enter}"]
    static ImageKeys := ["{Left}", "{Right}"]
    static SiYuanKeys := ["^{[}", "^{]}"]
    static ParentAltUp := "!{Up}"
    static ParentBackspace := "{Backspace}"

    __New(sender, caj, powerIso, matches := unset) {
        this.Sender := sender
        this.Caj := caj
        this.PowerIso := powerIso
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
                return this.Sender.SendChord(XButtonActions.DesktopKeys[index])
            case XButtonActions.Raw:
                if this.Matches.Call(WindowGroups.FolderUpAlt, hwnd)
                    && (!this.Matches.Call(WindowGroups.Explorer, hwnd) || !this.OverTaskbar())
                    keys := XButtonActions.ParentAltUp
                else if this.Matches.Call(WindowGroups.FolderUpBackspace, hwnd)
                    keys := XButtonActions.ParentBackspace
                else
                    keys := XButtonActions.RawKeys[index]
                return this.Sender.SendChord(keys)
        }
        if this.Matches.Call(WindowGroups.CajViewer, hwnd)
            return this.Caj.Navigate(hwnd, back, allowed)
        if this.Matches.Call(WindowGroups.PowerIso, hwnd)
            return this.PowerIso.Navigate(hwnd, back, allowed)
        if this.Matches.Call(WindowGroups.Anki, hwnd)
            keys := this.Matches.Call(WindowGroups.AnkiEditor, hwnd) ? XButtonActions.AnkiEditorKeys[index] : XButtonActions.AnkiKeys[index]
        else if this.Matches.Call(WindowGroups.NavigationAltShift, hwnd)
            keys := XButtonActions.AltShiftKeys[index]
        else if this.Matches.Call(WindowGroups.NavigationNative, hwnd)
            keys := XButtonActions.RawKeys[index]
        else if this.Matches.Call(WindowGroups.Cad, hwnd)
            keys := XButtonActions.CadKeys[index]
        else if this.Matches.Call(WindowGroups.NavigationBackspace, hwnd) {
            if !back
                return
            keys := XButtonActions.ParentBackspace
        } else if this.Matches.Call(WindowGroups.ImageViewer, hwnd)
            keys := XButtonActions.ImageKeys[index]
        else if this.Matches.Call(WindowGroups.SiYuan, hwnd)
            keys := XButtonActions.SiYuanKeys[index]
        else
            keys := XButtonActions.DefaultKeys[index]
        this.Sender.SendChord(keys)
    }

    OverTaskbar() {
        MouseGetPos(,, &hwnd)
        return this.Matches.Call(WindowGroups.Taskbar, hwnd)
    }
}
