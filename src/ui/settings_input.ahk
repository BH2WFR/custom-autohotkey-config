; 每个设置项复用自己的编辑窗口；仅在确认后调用保存命令。
class SettingsInputDialog {
    static Width := 416
    static Height := 136
    static TextHeight := 206
    static TextMinWidth := 360
    static TextMinHeight := 160
    static NoThousands := 0x80 ; UDS_NOTHOUSANDS
    Gui := 0

    __New(title, rule) {
        this.Title := title, this.Rule := rule
    }

    Open(current, commit) {
        if this.Gui {
            WinActivate(this.Gui.Hwnd)
            return
        }
        previous := GuiDpi.Enter()
        try {
            this.Commit := commit
            numeric := this.Rule.IsNumeric
            this.Gui := Gui("+AlwaysOnTop +ToolWindow -DPIScale" (numeric ? "" : " +Resize"), this.Title)
            this.Gui.SetFont("s9", "Microsoft YaHei UI")
            this.Hint := this.Gui.AddText("x12 y10 w392 h40", this.Rule.Hint)
            options := "x12 y54 w392 h24"
            if !numeric {
                ; 使用多行原生控件显示软折行，实际换行由设置规则决定。
                options .= " Multi VScroll" (this.Rule.Wrap ? " Wrap" : " -Wrap HScroll")
                options .= this.Rule.Multiline ? " WantReturn" : " -WantReturn"
            }
            this.Input := this.Gui.AddEdit(options, current)
            if numeric {
                this.Gui.AddUpDown("Range" this.Rule.Minimum "-" this.Rule.Maximum " +" SettingsInputDialog.NoThousands, current)
                this.Input.Text := String(current)
            }
            this.OK := this.Gui.AddButton("x244 y94 w76 h28 Default", "确定")
            this.Cancel := this.Gui.AddButton("x328 y94 w76 h28", "取消")
            this.OK.OnEvent("Click", ObjBindMethod(this, "Submit"))
            this.Cancel.OnEvent("Click", ObjBindMethod(this, "Close"))
            this.Gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.Gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.Dpi := GuiDpi(this.Gui, ObjBindMethod(this, "ResizeText"),
                numeric ? SettingsInputDialog.Width : SettingsInputDialog.TextMinWidth,
                numeric ? SettingsInputDialog.Height : SettingsInputDialog.TextMinHeight)
            this.Dpi.Apply(DllCall("GetDpiForWindow", "Ptr", this.Gui.Hwnd, "UInt"))
            if !numeric
                this.Gui.OnEvent("Size", ObjBindMethod(this, "ResizeText"))
            point := Buffer(8)
            position := DllCall("GetPhysicalCursorPos", "Ptr", point)
                ? "x" NumGet(point, 0, "Int") " y" NumGet(point, 4, "Int") " " : ""
            this.Gui.Show(position "w" this.Dpi.Px(SettingsInputDialog.Width) " h" this.Dpi.Px(numeric ? SettingsInputDialog.Height : SettingsInputDialog.TextHeight))
            this.Dpi.FitWindow()
            WinActivate(this.Gui.Hwnd)
            this.Input.Focus()
        } finally GuiDpi.Leave(previous)
    }

    ResizeText(*) {
        if !this.Gui || this.Rule.IsNumeric
            return
        this.Gui.GetClientPos(,, &width, &height)
        if !width || !height
            return
        margin := this.Dpi.Px(12), gap := this.Dpi.Px(8)
        fieldWidth := width - 2 * margin, buttonWidth := this.Dpi.Px(76)
        buttonY := height - margin - this.Dpi.Px(28)
        this.Hint.Move(,, fieldWidth)
        this.Input.Move(,, fieldWidth, buttonY - gap - this.Dpi.Px(54))
        this.Cancel.Move(width - margin - buttonWidth, buttonY)
        this.OK.Move(width - margin - 2 * buttonWidth - gap, buttonY)
    }

    Submit(*) {
        try {
            value := this.Rule.Parse(this.Input.Text)
            this.Commit.Call(value)
        } catch as err {
            this.Gui.Opt("+OwnDialogs")
            MsgBox(err.Message, this.Title, "Icon!")
            this.Input.Focus()
            return
        }
        this.Close()
    }

    Close(*) {
        this.Gui.Destroy()
        this.Dpi.Destroy()
        this.Gui := 0, this.Input := 0, this.Dpi := 0, this.Commit := 0
        this.Hint := 0, this.OK := 0, this.Cancel := 0
    }
}
