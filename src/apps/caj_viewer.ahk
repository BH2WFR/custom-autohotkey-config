class CajViewerActions {
    static Version7 := "7.0"
    static Version8 := "8.0"
    static Version9 := "9.0"
    static PdfTitle := "i)\.pdf(?:\]|$)"
    static Layout7 := {Menu: {X: 174, Y: 39}, Jump: {X: 237, Y: 430},
        Back: {X: 408, Y: 566}, Forward: {X: 408, Y: 543}}
    static Layout8Pdf := {Menu: {X: 102, Y: 39}, Jump: {X: 164, Y: 462},
        Back: {X: 335, Y: 633}, Forward: {X: 335, Y: 604}}
    static Layout8Caj := {Menu: {X: 102, Y: 39}, Jump: {X: 164, Y: 489},
        Back: {X: 335, Y: 659}, Forward: {X: 335, Y: 633}}
    static ExpandMenu := "^{Down}"
    static CloseMenu := "{Esc}"

    __New(automation) {
        this.Automation := automation
    }

    Navigate(hwnd, back, allowed) {
        version := FileGetVersion(WinGetProcessPath("ahk_id " hwnd))
        title := Trim(WinGetTitle("ahk_id " hwnd))
        steps := this.Plan(version, title, back)
        return this.Automation.Run(hwnd, steps, allowed)
    }

    Plan(version, title, back) {
        if VerCompare(version, CajViewerActions.Version7) < 0 || VerCompare(version, CajViewerActions.Version9) >= 0
            throw ValueError("CAJ Viewer 当前支持 7.x / 8.x 的前进后退。")
        legacy := VerCompare(version, CajViewerActions.Version8) < 0
        layout := legacy ? CajViewerActions.Layout7 : (RegExMatch(title, CajViewerActions.PdfTitle) ? CajViewerActions.Layout8Pdf : CajViewerActions.Layout8Caj)
        steps := [layout.Menu]
        if legacy
            steps.Push({Keys: CajViewerActions.ExpandMenu})
        steps.Push(layout.Jump, back ? layout.Back : layout.Forward, {Keys: CajViewerActions.CloseMenu})
        return steps
    }
}
