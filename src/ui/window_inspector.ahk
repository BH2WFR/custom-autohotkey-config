; 原生窗口信息视图；仅渲染快照并调用注入的命令。
class WindowInspectorView {
    static Title := "窗口信息查看器"
    static Width := 850
    static Height := 560
    static Margin := 8
    static Gap := 6
    static Row := 24
    static ListTop := 208
    static VerticalSeparator := 0x11 ; SS_ETCHEDVERT
    static ActionButtonWidth := 80
    static MiB := 1024 * 1024
    static ControlsPrompt := "请先点击『读取控件』按钮"
    static Priorities := ["Low", "BelowNormal", "Normal", "AboveNormal", "High", "Realtime"]
    Shown := false

    __New(commands) {
        previous := GuiDpi.Enter()
        try this.Build(commands)
        finally GuiDpi.Leave(previous)
    }

    Build(commands) {
        this.Commands := commands
        this.Gui := Gui("+Resize -DPIScale +AlwaysOnTop", WindowInspectorView.Title)
        this.Gui.SetFont("s9", "Microsoft YaHei UI")
        this.Gui.OnEvent("Close", (*) => this.Commands["Close"].Call())
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "Escape"))
        this.Finder := this.Gui.AddText("x8 y4 w34 h30 Center +0x100", "◎")
        this.Finder.SetFont("s18", "Segoe UI Symbol")
        this.Search := this.Gui.AddComboBox("x50 y8 w630 r12")
        this.ListButton := this.Button("刷新列表", "RefreshList", 686, 8, 80)
        this.FindButton := this.Button("查找", "Search", 772, 8, 70, "Default")
        this.Hidden := this.Gui.AddCheckbox("x8 y38 w118 h24", "包含隐藏窗口")
        this.Hidden.OnEvent("Click", (*) => this.Commands["RefreshList"].Call(this.Hidden.Value))
        this.Topmost := this.Gui.AddCheckbox("x132 y38 w64 h24 Checked", "置顶")
        this.Topmost.OnEvent("Click", (*) => this.SetTopmost(this.Topmost.Value))
        this.Button("刷新信息", "Refresh", 204, 38, 78)
        this.Button("读取控件", "Controls", 288, 38, 78)
        this.Priority := this.Gui.AddDropDownList("x522 y38 w140 r6 Choose3", WindowInspectorView.Priorities)
        this.Button("设置优先级", "Priority", 668, 38, 100)
        x := WindowInspectorView.Margin
        for item in [["文件属性", "Properties"], ["打开路径", "OpenPath"], [],
            ["激活窗口", "Activate"], ["窗口居中", "Center"], ["重置大小", "ResetSize"], ["显示边界", "ShowBorder"], [],
            ["关闭窗口", "CloseWindow"], ["重启进程", "Restart"], ["终止进程", "Terminate"]] {
            if item.Length {
                this.Button(item[1], item[2], x, 68, WindowInspectorView.ActionButtonWidth)
                x += WindowInspectorView.ActionButtonWidth
            } else {
                this.Gui.AddText("x" x " y71 w2 h18 +" WindowInspectorView.VerticalSeparator)
                x += 2
            }
            x += WindowInspectorView.Gap
        }
        this.Fields := Map()
        for index, label in ["标题", "进程", "路径", "命令行"] {
            y := 98 + (index - 1) * 26
            this.Gui.AddText("x8 y" y " w44 h22 +0x200", label)
            this.Fields[label] := this.Gui.AddEdit("x58 y" y " w784 h22 ReadOnly")
        }
        this.Info := this.Gui.AddListView("x8 y208 w330 h320 -Multi", ["项目", "值"])
        this.ControlList := this.Gui.AddListView("x344 y208 w498 h320 -Multi", ["序号", "HWND", "ClassNN", "文本", "Class", "位置及大小"])
        this.ResetControls()
        this.Info.OnEvent("DoubleClick", ObjBindMethod(this, "CopyInfo"))
        this.ControlList.OnEvent("DoubleClick", ObjBindMethod(this, "CopyControl"))
        this.Status := this.Gui.AddText("x8 y534 w834 h18", "双击列表项复制")
        this.Picker := WindowPickerView(this.Gui, this.Finder, commands["PickAtCursor"], commands["Pick"], ObjBindMethod(this, "SetStatus"))
        this.Dpi := GuiDpi(this.Gui, ObjBindMethod(this, "DpiChanged"), 810, 400)
        this.Dpi.Apply(DllCall("GetDpiForWindow", "Ptr", this.Handle, "UInt"))
        this.Gui.OnEvent("Size", ObjBindMethod(this, "Resize"))
    }

    Handle => this.Gui.Hwnd

    Escape(*) {
        if this.Picker.Dragging {
            this.Picker.Cancel()
            this.SetStatus("已取消选窗")
        } else
            this.Commands["Close"].Call()
    }

    Button(label, command, x, y, width := 78, options := "") {
        button := this.Gui.AddButton("x" x " y" y " w" width " h24 " options, label)
        button.OnEvent("Click", ObjBindMethod(this, "Dispatch", command))
        return button
    }

    Dispatch(command, *) {
        switch command {
            case "Search": this.Commands[command].Call(this.Search.Text, this.Hidden.Value)
            case "RefreshList": this.Commands[command].Call(this.Hidden.Value)
            case "Priority": this.Commands[command].Call(this.Priority.Text)
            default: this.Commands[command].Call()
        }
    }

    Show() {
        this.Gui.Opt(this.Topmost.Value ? "+AlwaysOnTop" : "-AlwaysOnTop")
        previous := GuiDpi.Enter()
        try this.Gui.Show(this.Shown ? "" : "w" this.Dpi.Px(WindowInspectorView.Width) " h" this.Dpi.Px(WindowInspectorView.Height))
        finally GuiDpi.Leave(previous)
        this.Shown := true
        this.Dpi.FitWindow()
        WinMoveTop(this.Handle)
        WinActivate(this.Handle)
    }

    SetTopmost(enabled) {
        this.Gui.Opt(enabled ? "+AlwaysOnTop" : "-AlwaysOnTop")
        this.Topmost.Value := enabled
    }

    SuspendTopmost() => this.Gui.Opt("-AlwaysOnTop")

    Highlight(hwnd, duration) => this.Picker.Border.Show(hwnd, duration)

    SetWindows(entries) {
        text := this.Search.Text, labels := []
        for entry in entries
            labels.Push(entry.Label)
        this.Search.Delete()
        this.Search.Add(labels)
        this.Search.Text := text
    }

    Render(data) {
        this.Picker.Border.Hide()
        this.Search.Text := "ID:" WindowInfo.Hex(data.Hwnd) ", " data.Title
        this.Fields["标题"].Value := data.Title
        this.Fields["进程"].Value := data.ProcessName
        this.Fields["路径"].Value := data.Path
        this.Fields["命令行"].Value := ""
        this.Info.Delete()
        this.ResetControls()
        b := data.Bounds
        rows := [["HWND", WindowInfo.Hex(data.Hwnd)], ["窗口类", data.Class], ["进程 PID", data.Pid],
            ["线程 ID", data.ThreadId], ["窗口状态", data.State], ["窗口置顶", this.YesNo(data.Topmost)],
            ["分层窗口", this.YesNo(data.Layered)], ["分层鼠标穿透", this.YesNo(data.LayeredClickThrough)],
            ["不透明度", Round(data.Opacity / 255 * 100) "%"], ["工具窗口", this.YesNo(data.ToolWindow)],
            ["点击不激活样式", this.YesNo(data.NoActivate)],
            ["位置（物理像素）", b.X ", " b.Y], ["大小（物理像素）", b.Width " × " b.Height],
            ["显示器缩放", Round(b.Scale * 100) "%"], ["Style", WindowInfo.Hex(data.Style)],
            ["ExStyle", WindowInfo.Hex(data.ExStyle)], ["所属进程窗口数", data.WindowCount],
            ["父窗口 HWND", WindowInfo.Hex(data.Parent)], ["父窗口标题", data.ParentTitle], ["父窗口类", data.ParentClass]]
        for row in rows
            this.Info.Add(, row*)
        this.BasicRows := this.Info.GetCount()
        this.Info.ModifyCol(1, this.Dpi.Px(128)), this.Info.ModifyCol(2, "AutoHdr")
        this.SetStatus("拖动左上角 ◎ 选窗；双击列表项复制")
    }

    RenderDetails(data, file) {
        while this.Info.GetCount() > this.BasicRows
            this.Info.Delete(this.Info.GetCount())
        this.Fields["命令行"].Value := data.CommandLine
        this.Priority.Choose(data.Priority)
        for row in [["进程启动时间", this.Time(data.Created)], ["用户", data.User], ["管理员权限", data.Elevated],
            ["进程架构", data.Architecture], ["优先级", data.Priority],
            ["工作集", this.Memory(data.WorkingSet)], ["虚拟内存", this.Memory(data.VirtualSize)],
            ["文件版本", file.Version], ["文件创建时间", this.Time(file.Created)], ["文件修改时间", this.Time(file.Modified)]]
            this.Info.Add(, row*)
        this.Info.ModifyCol(2, "AutoHdr")
    }

    Time(value) => value == "" ? "" : FormatTime(value, "yyyy-MM-dd HH:mm:ss")
    YesNo(value) => value ? "是" : "否"
    Memory(bytes) => IsNumber(bytes) ? Format("{:.2f} MiB", bytes / WindowInspectorView.MiB) : ""

    ResetControls() {
        this.ControlsLoaded := false
        this.ControlList.Delete()
        this.ControlList.Add(, WindowInspectorView.ControlsPrompt)
        this.ControlList.ModifyCol(1, "AutoHdr")
    }

    RenderControls(controls) {
        this.ControlsLoaded := true
        this.ControlList.Delete()
        for index, item in controls {
            b := item.Bounds
            this.ControlList.Add(, index, WindowInfo.Hex(item.Hwnd), item.Name, item.Text, item.Class,
                b.X ", " b.Y ", " b.Width " × " b.Height)
        }
        for index, width in [45, 100, 100, 190, 100, 170]
            this.ControlList.ModifyCol(index, this.Dpi.Px(width))
        this.SetStatus("已读取 " controls.Length " 个控件；坐标为屏幕物理像素")
    }

    CopyInfo(control, row) {
        if row
            this.Commands["Copy"].Call(control.GetText(row, 2))
    }

    CopyControl(control, row) {
        if !row || !this.ControlsLoaded
            return
        text := ""
        loop control.GetCount("Col")
            text .= (A_Index == 1 ? "" : "`t") control.GetText(row, A_Index)
        this.Commands["Copy"].Call(text)
    }

    SetStatus(text) => this.Status.Text := text

    Confirm(message) {
        return this.Dialog(message, "YesNo Icon? Default2") == "Yes"
    }

    Warn(message) => this.Dialog(message, "Icon!")

    Dialog(message, options) {
        this.Gui.Opt("+OwnDialogs")
        previous := GuiDpi.Enter()
        try return MsgBox(message, WindowInspectorView.Title, options)
        finally GuiDpi.Leave(previous)
    }

    DpiChanged() {
        this.Info.ModifyCol(1, this.Dpi.Px(128)), this.Info.ModifyCol(2, "AutoHdr")
        if this.ControlsLoaded {
            for index, width in [45, 100, 100, 190, 100, 170]
                this.ControlList.ModifyCol(index, this.Dpi.Px(width))
        } else
            this.ControlList.ModifyCol(1, "AutoHdr")
        this.Gui.GetClientPos(,, &width, &height)
        this.Resize(this.Gui, 0, width, height)
    }

    Resize(gui, state, width, height) {
        if state == -1
            return
        margin := this.Dpi.Px(WindowInspectorView.Margin), gap := this.Dpi.Px(WindowInspectorView.Gap)
        this.Search.Move(,, width - margin - this.Dpi.Px(50 + 162), GuiDpi.DropHeight(this.Search))
        this.ListButton.Move(width - margin - this.Dpi.Px(156))
        this.FindButton.Move(width - margin - this.Dpi.Px(70))
        for label, field in this.Fields
            field.Move(,, width - margin - this.Dpi.Px(58))
        usable := width - 2 * margin, left := Round((usable - gap) * 0.4)
        listHeight := height - this.Dpi.Px(WindowInspectorView.ListTop) - margin - this.Dpi.Px(WindowInspectorView.Row)
        this.Info.Move(,, left, listHeight)
        this.ControlList.Move(margin + left + gap,, usable - left - gap, listHeight)
        this.Status.Move(, height - margin - this.Dpi.Px(WindowInspectorView.Row) + gap, usable)
    }

    Destroy() {
        this.Picker.Destroy()
        this.Gui.Destroy()
        this.Dpi.Destroy()
        this.Commands.Clear()
    }
}
