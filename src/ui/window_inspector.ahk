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
    static ActionButtonWidth := 72
    static PushLike := 0x1000 ; BS_PUSHLIKE
    static MiB := 1024 * 1024
    static ControlsPrompt := "请先点击『读取控件』按钮"
    static WindowsPrompt := "请先按「刷新列表」加载所有窗口，或拖动左侧小圆饼到目标窗口"
    static LoadedPrompt := "轻按「刷新列表」刷新所有窗口列表，或将小圆饼拖动到目标窗口，以查看窗口信息"
    static SetComboCue := 0x1703 ; CB_SETCUEBANNER
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
        this.WindowEntries := [{Hwnd: 0, Pid: 0, Label: WindowInspectorView.WindowsPrompt}]
        this.ListLoaded := false
        this.CurrentIndex := 0
        this.ControlsLoaded := false
        this.TargetButtons := []
        this.Search := this.Gui.AddComboBox("x50 y8 w630 r12", [WindowInspectorView.WindowsPrompt])
        this.SetSearchHint(WindowInspectorView.WindowsPrompt)
        this.Search.OnEvent("Change", ObjBindMethod(this, "SelectionChanged"))
        this.ListButton := this.Button("刷新列表", "RefreshList", 686, 8, 80)
        this.FindButton := this.Button("查找", "Search", 772, 8, 70, "Default")
        this.Hidden := this.Gui.AddCheckbox("x8 y38 w104 h24", "包含隐藏窗口")
        this.Hidden.OnEvent("Click", (*) => this.ListLoaded && this.Commands["RefreshList"].Call(this.Hidden.Value))
        this.Topmost := this.Gui.AddCheckbox("x118 y38 w90 h24 Checked", "查看器置顶")
        this.Topmost.OnEvent("Click", (*) => this.SetTopmost(this.Topmost.Value))
        this.Button("刷新信息", "RefreshInfo", 214, 38, 66)
        this.Button("读取控件", "Controls", 286, 38, 66)
        separator := this.Gui.AddText("x0 y41 w2 h18 +" WindowInspectorView.VerticalSeparator)
        this.Priority := this.Gui.AddDropDownList("x0 y38 w110 r6 Disabled", WindowInspectorView.Priorities)
        this.ProcessControls := [separator, this.Priority, this.Button("设置优先级", "Priority", 0, 38, 80),
            this.Button("重启进程", "Restart", 0, 38, WindowInspectorView.ActionButtonWidth),
            this.Button("终止进程", "Terminate", 0, 38, WindowInspectorView.ActionButtonWidth)]
        x := WindowInspectorView.Margin
        for item in [["文件属性", "Properties"], ["打开路径", "OpenPath"], [],
            ["激活窗口", "Activate"], ["窗口居中", "Center"], ["重置大小", "ResetSize"], ["显示边界", "ShowBorder"],
            ["窗口置顶", "ToggleTopmost"], ["窗口穿透", "ToggleClickThrough"], [],
            ["最小化窗口", "Minimize"], ["关闭窗口", "CloseWindow"]] {
            if item.Length {
                switch item[2] {
                    case "ToggleTopmost": this.TargetTopmost := this.Toggle(item[1], item[2], x)
                    case "ToggleClickThrough": this.ClickThrough := this.Toggle(item[1], item[2], x)
                    default: this.Button(item[1], item[2], x, 68, WindowInspectorView.ActionButtonWidth)
                }
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
        this.Opacity := this.Gui.AddEdit("x0 y98 w40 h22 Number Limit3 Disabled")
        this.OpacityControls := [this.Gui.AddText("x0 y98 w60 h22 +0x200", "不透明度"), this.Opacity,
            this.Gui.AddText("x0 y98 w14 h22 +0x200", "%"), this.Button("应用", "SetOpacity", 0, 97, 48)]
        this.Info := this.Gui.AddListView("x8 y208 w330 h320 -Multi", ["项目", "值"])
        this.ControlList := this.Gui.AddListView("x344 y208 w498 h320 -Multi", ["序号", "HWND", "ClassNN", "文本", "Class", "位置及大小"])
        this.Info.OnEvent("DoubleClick", ObjBindMethod(this, "CopyInfo"))
        this.ControlList.OnEvent("DoubleClick", ObjBindMethod(this, "CopyControl"))
        this.Status := this.Gui.AddText("x8 y534 w834 h18", "双击列表项复制")
        this.Picker := WindowPickerView(this.Gui, this.Finder, commands["PickAtCursor"], commands["Pick"], ObjBindMethod(this, "SetStatus"))
        this.Dpi := GuiDpi(this.Gui, ObjBindMethod(this, "DpiChanged"), 810, 400)
        this.Dpi.Apply(DllCall("GetDpiForWindow", "Ptr", this.Handle, "UInt"))
        this.Gui.OnEvent("Size", ObjBindMethod(this, "Resize"))
    }

    Handle => this.Gui.Hwnd

    Toggle(label, command, x) {
        control := this.Gui.AddCheckbox("x" x " y68 w" WindowInspectorView.ActionButtonWidth " h24 Disabled +" WindowInspectorView.PushLike, label)
        control.OnEvent("Click", ObjBindMethod(this, "Dispatch", command))
        this.TargetButtons.Push(control)
        return control
    }

    Escape(*) {
        if this.Picker.Dragging {
            this.Picker.Cancel()
            this.SetStatus("已取消选窗")
        } else
            this.Commands["Close"].Call()
    }

    Button(label, command, x, y, width := 78, options := "") {
        button := this.Gui.AddButton("x" x " y" y " w" width " h24 " options, label)
        if command != "Search" && command != "RefreshList" {
            button.Enabled := false
            this.TargetButtons.Push(button)
        }
        button.OnEvent("Click", ObjBindMethod(this, "Dispatch", command))
        return button
    }

    Dispatch(command, *) {
        switch command {
            case "Search":
                if entry := this.SelectedEntry {
                    if entry.Hwnd
                        this.Commands["Select"].Call(entry)
                } else
                    this.Commands[command].Call(this.Search.Text, this.Hidden.Value)
            case "RefreshList": this.Commands[command].Call(this.Hidden.Value)
            case "Priority": this.Commands[command].Call(this.Priority.Text)
            case "SetOpacity": this.Commands[command].Call(this.Opacity.Value)
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

    SetSearchHint(hint) => SendMessage(WindowInspectorView.SetComboCue, 0, StrPtr(hint), this.Search)

    SetWindows(entries) {
        entries.InsertAt(1, {Hwnd: 0, Pid: 0, Label: WindowInspectorView.LoadedPrompt})
        this.WindowEntries := entries, this.ListLoaded := true, this.CurrentIndex := 0
        labels := []
        for entry in entries
            labels.Push(entry.Label)
        this.Search.Delete()
        this.Search.Add(labels)
        this.SetSearchHint(WindowInspectorView.LoadedPrompt)
    }

    SelectedEntry {
        get {
            index := this.Search.Value
            return index > 0 && index <= this.WindowEntries.Length ? this.WindowEntries[index] : 0
        }
    }

    SelectionChanged(*) {
        entry := this.SelectedEntry
        if entry && !entry.Hwnd {
            this.Search.Choose(this.CurrentIndex)
            return
        }
        this.Commands["Select"].Call(entry)
    }

    SelectWindow(data, append := true) {
        for index, entry in this.WindowEntries {
            if entry.Hwnd == data.Hwnd && entry.Pid == data.Pid {
                this.CurrentIndex := index
                this.Search.Choose(index)
                return true
            }
        }
        if !append
            return false
        ; 列表尚未加载时仅保留提示和通过热键、查找或圆饼选中的当前窗口。
        if !this.ListLoaded && this.WindowEntries.Length > 1 {
            this.WindowEntries.Pop()
            this.Search.Delete(2)
        }
        label := "ID:" WindowInfo.Hex(data.Hwnd) ", " data.Title
        this.WindowEntries.Push({Hwnd: data.Hwnd, Pid: data.Pid, Label: label})
        this.Search.Add([label])
        this.CurrentIndex := this.WindowEntries.Length
        this.Search.Choose(this.CurrentIndex)
        return true
    }

    EnableTarget(enabled) {
        for button in this.TargetButtons
            button.Enabled := enabled
        this.Priority.Enabled := enabled
        this.Opacity.Enabled := enabled
    }

    ClearTarget(keepQuery := false) {
        this.CurrentIndex := 0
        if !keepQuery {
            this.Search.Choose(0)
            this.Search.Text := ""
        }
        for label, field in this.Fields
            field.Value := ""
        this.Info.Delete(), this.ControlList.Delete()
        this.BasicRows := 0, this.ControlsLoaded := false
        this.Priority.Choose(0)
        this.TargetTopmost.Value := false
        this.ClickThrough.Value := false, this.Opacity.Value := ""
        this.EnableTarget(false)
        this.Picker.Border.Hide()
        this.SetStatus("请选择窗口")
    }

    Render(data) {
        this.Picker.Border.Hide()
        this.SelectWindow(data)
        this.EnableTarget(true)
        this.Priority.Choose(0)
        this.Fields["标题"].Value := data.Title
        this.Fields["进程"].Value := data.ProcessName
        this.Fields["路径"].Value := data.Path
        this.Fields["命令行"].Value := ""
        this.Info.Delete()
        this.ResetControls()
        this.RenderBasic(data)
        this.SetStatus("拖动左上角 ◎ 选窗；双击列表项复制")
    }

    RenderBasic(data) {
        this.TargetTopmost.Value := data.Topmost
        this.ClickThrough.Value := data.LayeredClickThrough
        percent := Round(data.Opacity * 100 / WindowTools.Opaque)
        this.Opacity.Value := percent
        b := data.Bounds
        rows := [["HWND", WindowInfo.Hex(data.Hwnd)], ["窗口类", data.Class], ["进程 PID", data.Pid],
            ["线程 ID", data.ThreadId], ["窗口状态", data.State], ["窗口置顶", this.YesNo(data.Topmost)],
            ["分层窗口", this.YesNo(data.Layered)], ["分层鼠标穿透", this.YesNo(data.LayeredClickThrough)],
            ["不透明度", percent "%"], ["工具窗口", this.YesNo(data.ToolWindow)],
            ["点击不激活样式", this.YesNo(data.NoActivate)],
            ["位置（物理像素）", b.X ", " b.Y], ["大小（物理像素）", b.Width " × " b.Height],
            ["显示器缩放", Round(b.Scale * 100) "%"], ["Style", WindowInfo.Hex(data.Style)],
            ["ExStyle", WindowInfo.Hex(data.ExStyle)], ["所属进程窗口数", data.WindowCount],
            ["父窗口 HWND", WindowInfo.Hex(data.Parent)], ["父窗口标题", data.ParentTitle], ["父窗口类", data.ParentClass]]
        updating := this.Info.GetCount() > 0
        for index, row in rows {
            if updating
                this.Info.Modify(index,, row*)
            else
                this.Info.Add(, row*)
        }
        this.BasicRows := rows.Length
        this.Info.ModifyCol(1, this.Dpi.Px(128)), this.Info.ModifyCol(2, "AutoHdr")
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
        this.AlignRight(this.ProcessControls, width - margin, gap)
        titleRight := this.AlignRight(this.OpacityControls, width - margin, gap)
        for label, field in this.Fields
            field.Move(,, (label == "标题" ? titleRight : width - margin) - this.Dpi.Px(58))
        usable := width - 2 * margin, left := Round((usable - gap) * 0.4)
        listHeight := height - this.Dpi.Px(WindowInspectorView.ListTop) - margin - this.Dpi.Px(WindowInspectorView.Row)
        this.Info.Move(,, left, listHeight)
        this.ControlList.Move(margin + left + gap,, usable - left - gap, listHeight)
        this.Status.Move(, height - margin - this.Dpi.Px(WindowInspectorView.Row) + gap, usable)
    }

    AlignRight(controls, right, gap) {
        loop controls.Length {
            control := controls[-A_Index]
            control.GetPos(,, &controlWidth)
            control.Move(right - controlWidth)
            right -= controlWidth + gap
        }
        return right
    }

    Destroy() {
        this.Picker.Destroy()
        this.Gui.Destroy()
        this.Dpi.Destroy()
        this.Commands.Clear()
    }
}
