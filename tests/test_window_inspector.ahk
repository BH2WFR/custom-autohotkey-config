#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ../src/lib/window.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/lib/window_info.ahk
#Include ../src/lib/process.ahk
#Include ../src/lib/shell.ahk
#Include ../src/actions/window.ahk
#Include ../src/rules/windows.ahk
#Include ../src/ui/window_picker.ahk
#Include ../src/ui/window_inspector.ahk
#Include ../src/ui/dpi_gui.ahk
#Include ../src/actions/window_inspector.ahk
#Include ../src/actions/window_inspector_launcher.ahk

class WindowInspectorTests {
    static Count := 0
    static OkButton := "Button1", NoButton := "Button2"
    static ButtonClick := 0x00F5
    static DialogTimeout := 5000, SuiteTimeout := 60000
    static ExpectedDialog := 0

    static WatchDialogs() {
        expected := this.ExpectedDialog
        if A_TickCount - this.Started >= this.SuiteTimeout
            this.Fail("Window inspector test timed out")
        if expected && A_TickCount - expected.Started >= this.DialogTimeout
            this.Fail("Timed out waiting for dialog to close: " expected.Command)
        hwnd := WinExist("ahk_class #32770 ahk_pid " ProcessExist())
        if !hwnd
            return
        if !expected || DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr") != expected.Owner
            this.Fail("Unexpected test dialog: " WinGetTitle(hwnd) " " WinGetText(hwnd))
        if expected.Clicked
            return
        button := ControlGetHwnd(expected.Button, hwnd)
        expected.Text := WinGetText(hwnd), expected.Clicked := true
        PostMessage(this.ButtonClick, 0, 0, button)
    }

    static AnswerDialog(view, command, button) {
        expected := {Owner: view.Handle, Command: command, Button: button, Started: A_TickCount, Clicked: false, Text: ""}
        this.ExpectedDialog := expected
        try view.Dispatch(command)
        finally this.ExpectedDialog := 0
        this.Assert(expected.Clicked, "Expected dialog for " command)
        return expected.Text
    }

    static Fail(message, *) {
        FileAppend((message is Error ? message.Message "`n" message.Stack : message) "`n", "**")
        ExitApp(1)
    }
    class Tip {
        Show(text, *) => this.Text := text
    }
    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }
    static PickerTest(view, actions, owner) {
        popup := Gui("+Owner" owner.Hwnd " +AlwaysOnTop", "Inspector popup")
        popup.AddText(, "广告来源选窗测试")
        popup.Show("x20 y20 w180 h70 NA")
        point := Buffer(8)
        DllCall("GetPhysicalCursorPos", "Ptr", point)
        try {
            finder := WindowGeometry.Measure(view.Finder.Hwnd)
            if DllCall("SetPhysicalCursorPos", "Int", finder.X + finder.Width // 2, "Int", finder.Y + finder.Height // 2) {
                tip := WinWait("ahk_class tooltips_class32 ahk_pid " ProcessExist(),, 1)
                this.Assert(tip && ControlGetText(tip) == WindowPickerView.Hint, "Hover over finder displays its tooltip")
            }
            b := WindowGeometry.Measure(popup.Hwnd)
            if !DllCall("SetPhysicalCursorPos", "Int", b.X + 40, "Int", b.Y + 40) {
                FileAppend("SKIP pointer hit-test: input desktop unavailable`n", "*")
                return
            }
            this.Assert(WindowInfo.AtCursor() == popup.Hwnd, "Physical hit-test keeps owned popup instead of its owner")
            this.Assert(!view.Picker.Hovering || WinWaitClose(tip,, 1), "Leaving finder hides its tooltip")
            PostMessage(WindowPickerView.MouseDown, 0, 0, view.Finder.Hwnd)
            Sleep(50)
            this.Assert(view.Picker.Dragging, "Actual finder mouse message starts drag")
            PostMessage(WindowPickerView.MouseMove, 0, 0, view.Handle)
            Sleep(50)
            this.Assert(view.Picker.Target == popup.Hwnd, "Captured mouse movement selects actual popup")
            PostMessage(WindowPickerView.MouseUp, 0, 0, view.Handle)
            deadline := A_TickCount + 1000
            while (view.Picker.Dragging || actions.Data.Hwnd != popup.Hwnd) && A_TickCount < deadline
                Sleep(10)
            this.Assert(actions.Data.Hwnd == popup.Hwnd && !view.Picker.Dragging
                && !DllCall("GetCapture", "Ptr"), "Release loads popup and clears capture: data=" actions.Data.Hwnd
                " popup=" popup.Hwnd " dragging=" view.Picker.Dragging " capture=" DllCall("GetCapture", "Ptr") " status=" view.Status.Text)
            this.Assert(view.Info.GetCount() == view.BasicRows + 10 && InStr(view.Fields["命令行"].Value, "test_window_inspector.ahk"), "Picked popup immediately loads process details")
            for edge in view.Picker.Border.Edges
                this.Assert(!DllCall("IsWindowVisible", "Ptr", edge.Hwnd), "Release hides highlight edge")
        } finally {
            view.Picker.Cancel()
            DllCall("SetPhysicalCursorPos", "Int", NumGet(point, 0, "Int"), "Int", NumGet(point, 4, "Int"))
            popup.Destroy()
        }
    }

    static SelectionTest(view, actions, target) {
        second := Gui(, target.Title)
        second.AddEdit(, "来自另一个同名窗口")
        second.Show("x40 y60 w280 h100 NA")
        hwnd := second.Hwnd
        try {
            items := ControlGetItems(view.Search)
            this.Assert(items.Length == 2 && items[1] == WindowInspectorView.WindowsPrompt, "Unloaded list contains the refresh instruction")
            ControlChooseIndex(1, view.Search)
            Sleep(50)
            this.Assert(view.SelectedEntry.Hwnd == target.Hwnd && actions.Data.Hwnd == target.Hwnd
                && view.Search.Text == items[2], "Choosing the instruction leaves the current window selected")
            ControlClick(view.ListButton)
            Sleep(100)
            this.Assert(view.ListLoaded && view.SelectedEntry.Hwnd == target.Hwnd, "Refresh button loads windows and retains selection")
            this.Assert(actions.Tooltip.Text == "列表已刷新，共 " (ControlGetItems(view.Search).Length - 1) " 个窗口", "List tooltip excludes the instruction row")
            this.Assert(ControlGetItems(view.Search)[1] == WindowInspectorView.LoadedPrompt, "Loaded list retains its instruction")
            ControlChooseIndex(1, view.Search)
            Sleep(50)
            this.Assert(view.SelectedEntry.Hwnd == target.Hwnd && actions.Data.Hwnd == target.Hwnd, "Loaded instruction preserves selection")
            for index, entry in view.WindowEntries {
                if entry.Hwnd == hwnd
                    secondIndex := index
                if entry.Hwnd == target.Hwnd
                    firstIndex := index
            }
            ControlChooseIndex(secondIndex, view.Search)
            Sleep(80)
            this.Assert(actions.Data.Hwnd == hwnd && view.Info.GetText(1, 2) == WindowInfo.Hex(hwnd)
                && view.Fields["标题"].Value == second.Title && view.Fields["命令行"].Value != "",
                "Native selection immediately shows the selected window and process")
            for expected in [true, false] {
                ControlClick(view.TargetTopmost)
                Sleep(80)
                this.Assert(view.TargetTopmost.Value == expected && actions.Data.Topmost == expected
                    && !!(WinGetExStyle(hwnd) & WindowTools.TopmostStyle) == expected,
                    "Toggle changes selected HWND and renders actual topmost style")
                this.Assert(view.Topmost.Value && !(WinGetExStyle(target.Hwnd) & WindowTools.TopmostStyle),
                    "Viewer and other window keep their own topmost states")
            }
            for initial in [100, 37] {
                view.Opacity.Value := initial
                ControlClick("应用", view.Handle)
                Sleep(80)
                this.Assert(WindowTools.GetOpacity(hwnd) == Round(initial * 255 / 100), "Apply selected window opacity")
                this.Assert(actions.Tooltip.Text == "不透明度已设为 " initial "%", "Applied opacity tooltip")
                for enabled in [true, false] {
                    ControlClick(view.ClickThrough)
                    Sleep(80)
                    alpha := enabled ? (initial == 100 ? 150 : Round(initial * 255 / 100)) : 255
                    percent := Round(alpha * 100 / 255)
                    info := ListViewGetContent(, view.Info)
                    this.Assert(WindowTools.GetOpacity(hwnd) == alpha && !!(WinGetExStyle(hwnd) & WindowTools.TopmostStyle) == enabled
                        && !!(WinGetExStyle(hwnd) & WindowTools.TransparentStyle) == enabled, "Inspector applies Caps+B window styles")
                    this.Assert(view.ClickThrough.Value == enabled && view.TargetTopmost.Value == enabled && view.Opacity.Value == percent
                        && InStr(info, "不透明度`t" percent "%") && InStr(info, "分层鼠标穿透`t" (enabled ? "是" : "否")),
                        "Buttons, opacity editor and information list reflect native styles")
                }
            }
            for button in view.TargetButtons
                if button.Text == "读取控件"
                    ControlClick(button)
            Sleep(80)
            this.Assert(view.ControlList.GetText(1, 4) == "来自另一个同名窗口", "Read controls button uses the selected HWND")
            this.Assert(actions.Tooltip.Text == "已读取 1 个控件", "Controls tooltip gives count")
            priority := view.Priority.Text
            ControlClick("设置优先级", view.Handle)
            Sleep(80)
            this.Assert(actions.Tooltip.Text == "进程优先级已设为 " priority, "Priority button confirms selected priority")
            confirmation := this.AnswerDialog(view, "CloseWindow", this.NoButton)
            this.Assert(InStr(confirmation, second.Title) && WinExist(hwnd), "Auto-click No keeps the selected test window open")
            ControlChooseIndex(firstIndex, view.Search)
            Sleep(50)
            this.Assert(view.ControlList.GetText(1) == WindowInspectorView.ControlsPrompt, "New selection clears the previous controls")
            second.Destroy()
            ControlChooseIndex(secondIndex, view.Search)
            Sleep(80)
            this.Assert(!actions.Data && !view.Search.Value && view.Search.Text == ""
                && !view.Info.GetCount() && !view.ControlList.GetCount() && !view.Priority.Value, "Stale native selection clears all lists and selection")
            this.Assert(ControlGetItems(view.Search)[1] == WindowInspectorView.LoadedPrompt && !view.Opacity.Enabled, "Empty selection retains instruction and disables opacity")
            for label, field in view.Fields
                this.Assert(field.Value == "", "Clears field " label)
            for button in view.TargetButtons
                this.Assert(!button.Enabled, "Disables action " button.Text)
            ControlChooseIndex(firstIndex, view.Search)
            Sleep(50)
            this.Assert(actions.Target().Hwnd == target.Hwnd && view.Priority.Enabled, "Choosing a live window enables actions again")
        } finally {
            try second.Destroy()
        }
    }

    static HostUpdates(target) {
        settings := {passThroughOpacityPercent: 42}
        tip := this.Tip(), launcher := WindowInspectorLauncher(A_ScriptDir "\..", tip, settings)
        windows := WindowActions(tip, settings, ObjBindMethod(launcher, "NotifyStyleChanged"))
        context := {Hwnd: target.Hwnd}
        try {
            launcher.Open(context)
            viewer := WinWait(WindowInspectorView.Title " ahk_pid " launcher.Pid,, 3)
            this.Assert(viewer, "Independent inspector opened")
            deadline := A_TickCount + 2000
            while !InStr(ListViewGetContent(, "SysListView321", viewer), "文件修改时间") && A_TickCount < deadline
                Sleep(20)
            for enabled in [true, false] {
                windows.TogglePassThrough(context)
                expected := "不透明度`t" (enabled ? 42 : 100) "%"
                deadline := A_TickCount + 2000
                loop {
                    Sleep(25)
                    info := ListViewGetContent(, "SysListView321", viewer)
                } until InStr(info, expected) || A_TickCount >= deadline
                this.Assert(InStr(info, expected) && ControlGetChecked("窗口穿透", viewer) == enabled
                    && ControlGetChecked("窗口置顶", viewer) == enabled, "Caps+B updates the open inspector worker: enabled=" enabled
                    " alpha=" WindowTools.GetOpacity(target.Hwnd) " pass=" ControlGetChecked("窗口穿透", viewer)
                    " top=" ControlGetChecked("窗口置顶", viewer) " matched=" InStr(info, expected))
            }
            for percent in [42, 0, 100] {
                if percent != 42 {
                    settings.passThroughOpacityPercent := percent
                    launcher.SyncSettings()
                }
                for enabled in [true, false] {
                    ControlClick("窗口穿透", viewer)
                    deadline := A_TickCount + 2000
                    loop {
                        Sleep(20)
                        actual := WindowInfo.Read(target.Hwnd)
                    } until actual.LayeredClickThrough == enabled || A_TickCount >= deadline
                    this.Assert(actual.LayeredClickThrough == enabled && actual.Opacity == (enabled ? Round(percent * 255 / 100) : 255),
                        "Open inspector uses current pass-through percentage " percent)
                    this.Assert(this.WaitForTooltip(launcher.Pid, enabled ? "已开启窗口穿透" : "已关闭窗口穿透"),
                        "Pass-through button displays its new state")
                }
            }
            ControlClick("刷新信息", viewer)
            this.Assert(this.WaitForTooltip(launcher.Pid, "窗口信息已刷新"), "Refresh button displays the native result tooltip")
        } finally {
            windows.Stop()
            launcher.Close()
        }
    }

    static WaitForTooltip(pid, expected) {
        deadline := A_TickCount + 2000
        loop {
            for hwnd in WinGetList("ahk_class tooltips_class32 ahk_pid " pid)
                if ControlGetText(hwnd) == expected
                    return true
            Sleep(20)
        } until A_TickCount >= deadline
        return false
    }

    static StyleTest(view, actions, target) {
        overlay := Gui("+ToolWindow +AlwaysOnTop +E0x08000020", "Inspector style test")
        try {
            actions.Load(overlay.Hwnd)
            this.Assert(view.TargetTopmost.Value, "Newly loaded topmost window shows pressed toggle")
            this.Assert(!actions.Data.LayeredClickThrough, "Transparent style alone does not imply layered click-through")
            WinSetTransparent(200, overlay.Hwnd)
            actions.Refresh()
            rows := Map()
            loop view.Info.GetCount()
                rows[view.Info.GetText(A_Index, 1)] := view.Info.GetText(A_Index, 2)
            for label in ["窗口置顶", "分层窗口", "分层鼠标穿透", "工具窗口", "点击不激活样式"]
                this.Assert(rows[label] == "是", "Inspector identifies target style: " label)
            overlay.Opt("-AlwaysOnTop")
            actions.Refresh()
            this.Assert(!view.TargetTopmost.Value, "Refresh reads externally changed topmost style")
            loop view.Info.GetCount() {
                if view.Info.GetText(A_Index, 1) == "窗口置顶"
                    this.Assert(view.Info.GetText(A_Index, 2) == "否", "Refresh reflects removal of topmost style")
            }
        } finally {
            overlay.Destroy()
            actions.Load(target.Hwnd)
        }
    }
    static Run() {
        this.Started := A_TickCount
        OnError(ObjBindMethod(this, "Fail"))
        SetTimer(ObjBindMethod(this, "WatchDialogs"), 50)
        target := Gui(, "Inspector test 中文窗口"), other := Gui(, "Inspector second window")
        edit := target.AddEdit("w300", "控件内容 test")
        target.AddButton(, "测试按钮")
        target.Show("x100 y100 w400 h200 NA")
        tip := this.Tip(), actions := WindowInspectorActions(WindowInspectorView, WindowActions(tip, {passThroughOpacityPercent: 59}), tip)
        savedClipboard := ClipboardAll()
        try {
            beforeHidden := A_DetectHiddenWindows, beforeMode := A_TitleMatchMode
            data := WindowInfo.Read(target.Hwnd)
            this.Assert(data.Title == target.Title && data.Pid == ProcessExist(), "Actual target title and PID")
            this.Assert(data.Bounds.Width == WindowGeometry.Measure(target.Hwnd).Width && data.Bounds.Scale > 0, "Physical bounds and monitor scaling")
            this.Assert(WindowInfo.Find("Inspector test") == target.Hwnd, "Substring title search")
            this.Assert(WindowInfo.Find("ID:" WindowInfo.Hex(target.Hwnd) ", label") == target.Hwnd, "Window list label search")
            this.Assert(WindowInfo.Find("ahk_id " other.Hwnd, true) == other.Hwnd, "Hidden-window search")
            this.Assert(WindowInfo.Find("ahk_id " other.Hwnd, false) == 0, "Hidden windows excluded by default")
            this.Assert(A_DetectHiddenWindows == beforeHidden && A_TitleMatchMode == beforeMode, "Query settings restored")
            controls := WindowInfo.Controls(target.Hwnd)
            this.Assert(controls.Length == 2 && controls[1].Text == "控件内容 test", "Native control text, including Unicode")
            this.Assert(controls[1].Name == "Edit1" && controls[1].Hwnd == edit.Hwnd, "ClassNN and HWND remain paired")
            process := ProcessTools.Read(data.Pid)
            this.Assert(InStr(process.CommandLine, "test_window_inspector.ahk") && process.Architecture == "x64", "Actual native command line and process architecture")
            this.Assert(process.VirtualSize > process.WorkingSet && SubStr(process.Created, 1, 8) == SubStr(A_Now, 1, 8), "Native memory counters and local creation time")
            this.Assert(process.User != "" && process.Priority != "" && process.WorkingSet > 0, "Process owner, priority and memory")
            this.Assert(ProcessTools.FileInfo(data.Path).Version != "", "Executable file version")
            this.HostUpdates(target)
            actions.Open({Hwnd: target.Hwnd})
            view := actions.View, handle := view.Handle
            this.SelectionTest(view, actions, target)
            this.StyleTest(view, actions, target)
            blocker := Gui("+AlwaysOnTop", "Inspector topmost regression")
            try {
                blocker.Show("w300 h100 NA")
                view.Show()
                order := WinGetList()
                for hwnd in order {
                    if hwnd == handle || hwnd == blocker.Hwnd {
                        this.Assert(hwnd == handle, "Reopened inspector is above an existing topmost window")
                        break
                    }
                }
            } finally blocker.Destroy()
            this.Assert(actions.Data.Hwnd == target.Hwnd && view.Fields["标题"].Value == target.Title, "Captures original target before showing GUI")
            for button in view.TargetButtons
                if button.Text == "最小化窗口"
                    minimize := button
            popup := Gui("-MinimizeBox", "Inspector hide test")
            try {
                popup.Show("w200 h80 NA")
                actions.Load(popup.Hwnd)
                ControlClick(minimize)
                Sleep(100)
                this.Assert(!DllCall("IsWindowVisible", "Ptr", popup.Hwnd) && actions.Data.State == "隐藏"
                    && view.SelectedEntry.Hwnd == popup.Hwnd, "Minimize button hides popup without a minimize box and keeps selection")
                this.Assert(tip.Text == "窗口状态：隐藏", "Hidden popup tooltip")
                view.Dispatch("Activate")
                this.Assert(WinActive(popup.Hwnd) && actions.Data.Visible, "Activate brings back hidden target")
            } finally popup.Destroy()
            actions.Open({Hwnd: target.Hwnd})
            ControlClick(minimize)
            Sleep(100)
            this.Assert(WinGetMinMax(target.Hwnd) == -1 && actions.Data.State == "最小化", "Minimize button minimizes selected normal window")
            this.Assert(tip.Text == "窗口状态：最小化", "Minimized window tooltip")
            view.Show()
            this.Assert(InStr(this.BorderWarning(view), "最小化") && WinGetMinMax(target.Hwnd) == -1, "Border-only warns and leaves minimized target minimized")
            actions.Activate()
            edgeHwnd := view.Picker.Border.Edges[1].Hwnd
            this.Assert(WinActive(target.Hwnd) && WinGetMinMax(target.Hwnd) != -1 && tip.Text == "窗口已激活`n3 秒后切回窗口信息查看器", "Activation shows a two-line return notice without the title")
            this.Assert(DllCall("IsWindowVisible", "Ptr", edgeHwnd), "Restored target has a visible preview border")
            returned := A_TickCount
            this.Assert(WinWaitActive(handle,, 4) && A_TickCount - returned >= 2700, "Inspector regains focus after the three-second preview")
            this.Assert(!DllCall("IsWindowVisible", "Ptr", edgeHwnd), "Activation border expires")
            this.Assert(view.Topmost.Value && (WinGetExStyle(handle) & WindowTools.TopmostStyle), "Preview restores previous topmost preference")
            view.Dispatch("ShowBorder")
            this.Assert(WinActive(handle) && DllCall("IsWindowVisible", "Ptr", edgeHwnd), "Border-only keeps focus on inspector")
            expected := WindowGeometry.VisibleFrame(target.Hwnd), drawn := WindowGeometry.Measure(edgeHwnd)
            this.Assert(drawn.X == expected.X && drawn.Y == expected.Y && drawn.Width == expected.Width, "Border matches target's visible frame")
            Sleep(3200)
            this.Assert(!DllCall("IsWindowVisible", "Ptr", edgeHwnd) && WinActive(handle), "Border-only expires without a focus change")
            this.Assert(view.Info.GetCount() == view.BasicRows + 10 && InStr(view.Fields["命令行"].Value, "test_window_inspector.ahk"), "Opening immediately loads process details")
            this.Assert(view.ControlList.GetCount() == 1 && view.ControlList.GetText(1) == WindowInspectorView.ControlsPrompt,
                "Unread controls list shows instruction")
            hasDetailsButton := false
            for control in view.Gui
                if control.Type == "Button" && control.Text == "进程详情"
                    hasDetailsButton := true
            this.Assert(!hasDetailsButton, "No manual process details button")
            actions.Controls()
            if A_Args.Length && A_Args[1] == "--preview" {
                FileAppend(handle, A_ScriptDir "\..\tmp\inspector_preview_hwnd.txt", "UTF-8")
                Sleep(15000)
            }
            this.Assert(view.Info.GetCount() == view.BasicRows + 10 && view.ControlList.GetCount() == 2, "Native lists show basic, process and control data")
            actions.Refresh()
            this.Assert(view.Info.GetCount() == view.BasicRows + 10 && InStr(view.Fields["命令行"].Value, "test_window_inspector.ahk"), "Refresh automatically replaces process details")
            this.Assert(!view.ControlsLoaded && view.ControlList.GetText(1) == WindowInspectorView.ControlsPrompt, "Refresh resets controls prompt")
            actions.Controls()
            view.CopyInfo(view.Info, 1)
            this.Assert(A_Clipboard == WindowInfo.Hex(target.Hwnd) && tip.Text == "已复制", "Double-click property copies its value")
            view.CopyControl(view.ControlList, 1)
            this.Assert(InStr(A_Clipboard, "控件内容 test"), "Double-click control copies row")
            actions.Open({Hwnd: handle})
            this.Assert(actions.Data.Hwnd == target.Hwnd, "Reopening from inspector retains target")
            actions.Open({Hwnd: other.Hwnd})
            this.Assert(actions.View.Handle == handle && actions.Data.Hwnd == other.Hwnd, "Singleton updates to another target")
            this.Assert(!view.ControlsLoaded && view.ControlList.GetText(1) == WindowInspectorView.ControlsPrompt, "Changing target resets controls prompt")
            actions.RefreshList(true)
            this.Assert(ControlGetItems(view.Search).Length > 0, "Native dropdown receives window list")
            actions.Search("Inspector test", false)
            actions.Center()
            this.Assert(actions.Data.Hwnd == target.Hwnd, "Center operates on inspected window")
            border := view.Picker.Border
            border.Show(target.Hwnd)
            bounds := WindowGeometry.VisibleFrame(target.Hwnd), edge := WindowGeometry.Measure(border.Edges[1].Hwnd)
            thickness := Round(WindowHighlightView.Thickness * bounds.Scale)
            this.Assert(edge.X == bounds.X && edge.Y == bounds.Y
                && edge.Width == bounds.Width && edge.Height == thickness, "Drag highlight is inside the visible frame at monitor scale")
            this.Assert((WinGetExStyle(border.Edges[1].Hwnd) & 0x08080020) == 0x08080020, "Highlight is layered, click-through and non-activating")
            border.Hide()
            this.MaximizedBorder(border)
            view.Picker.Message(0, 0, WindowPickerView.MouseDown, view.Finder.Hwnd)
            this.Assert(view.Picker.Dragging && DllCall("GetCapture", "Ptr") == handle, "Finder captures drag outside its control")
            view.Escape()
            this.Assert(!view.Picker.Dragging && !DllCall("GetCapture", "Ptr"), "Escape cancels capture without closing viewer")
            this.PickerTest(view, actions, target)
            actions.Load(target.Hwnd)
            view.Gui.Show("w" view.Dpi.Px(view.Dpi.MinWidth) " NA")
            Sleep(100)
            this.ProcessLayout(view)
            view.Gui.Show("w1200 h750 NA")
            Sleep(100)
            this.ProcessLayout(view)
            view.Info.GetPos(&leftX,, &leftW), view.ControlList.GetPos(&rightX,, &rightW)
            this.Assert(leftX + leftW < rightX && rightW > leftW, "Resized lists retain gap and proportions")
            this.DpiTest(view)
            closedHwnd := other.Hwnd
            actions.Load(closedHwnd)
            other.Destroy()
            this.Assert(InStr(this.BorderWarning(view), "无法显示窗口边界"), "Destroyed target produces a warning dialog")
            actions.Load(target.Hwnd)
            actions.Invoke("Load", closedHwnd)
            this.Assert(view.Status.Text != "" && !actions.Data && !view.SelectedEntry, "Closed target clears the previous snapshot")
            view.Picker.Message(0, 0, WindowPickerView.MouseDown, view.Finder.Hwnd)
            actions.Close()
            this.Assert(!DllCall("IsWindow", "Ptr", handle) && !DllCall("GetCapture", "Ptr"), "Closing during drag releases capture and native GUI")
            actions.Open({Hwnd: target.Hwnd})
            this.Assert(actions.View.Handle && actions.Data.Hwnd == target.Hwnd, "Viewer reopens after complete cleanup")
        } finally {
            actions.Close()
            target.Destroy()
            try other.Destroy()
            A_Clipboard := savedClipboard
        }
        this.Assert(!actions.View && !actions.Data, "Close releases GUI and target")
        FileAppend("PASS " this.Count " window inspector checks`n", "*")
    }

    static BorderWarning(view) => this.AnswerDialog(view, "ShowBorder", this.OkButton)

    static MaximizedBorder(border) {
        testGui := Gui("+Resize", "Maximized inspector border")
        previous := GuiDpi.Enter()
        try {
            monitor := Min(2, MonitorGetCount())
            MonitorGet(monitor, &left, &top, &right, &bottom)
            testGui.Show("NA x" (left + 50) " y" (top + 50) " w300 h200")
            WinMaximize(testGui.Hwnd)
            for duration in [0, WindowInspectorActions.PreviewMs] {
                border.Show(testGui.Hwnd, duration)
                for edge in border.Edges {
                    b := WindowGeometry.Measure(edge.Hwnd)
                    this.Assert(b.X >= left && b.Y >= top && b.X + b.Width <= right && b.Y + b.Height <= bottom,
                        "All four edges stay inside maximized window monitor " monitor)
                }
            }
            FileAppend("Verified maximized border on monitor " monitor "`n", "*")
        } finally {
            border.Hide()
            testGui.Destroy()
            GuiDpi.Leave(previous)
        }
    }

    static ProcessLayout(view) {
        view.Gui.GetClientPos(,, &width)
        ControlGetPos(&left, &row, &leftWidth,, "读取控件", view.Handle)
        view.ProcessControls[1].GetPos(&divider,, &dividerWidth)
        view.Priority.GetPos(&priorityLeft)
        this.Assert(left + leftWidth < divider && divider + dividerWidth < priorityLeft, "Divider precedes priority dropdown")
        edge := left + leftWidth, gap := view.Dpi.Px(WindowInspectorView.Gap)
        for control in [view.Priority, "设置优先级", "重启进程", "终止进程"] {
            ControlGetPos(&x, &y, &w,, control, view.Handle)
            this.Assert(x >= edge + gap && y == row, "Process controls share a row with space between controls")
            edge := x + w
        }
        this.Assert(width - edge == view.Dpi.Px(WindowInspectorView.Margin), "Process controls align with the right margin")
    }

    static DpiTest(view) {
        context := DllCall("GetWindowDpiAwarenessContext", "Ptr", view.Handle, "Ptr")
        this.Assert(DllCall("AreDpiAwarenessContextsEqual", "Ptr", context, "Ptr", GuiDpi.PerMonitorV2), "Inspector uses Per-Monitor V2")
        previous := GuiDpi.Enter()
        try {
            actualDpi := DllCall("GetDpiForWindow", "Ptr", view.Handle, "UInt")
            font := SendMessage(GuiDpi.GetFontMessage, 0, 0, view.Status.Hwnd)
            data := Buffer(GuiDpi.LogFontBytes)
            DllCall("gdi32\GetObjectW", "Ptr", font, "Int", data.Size, "Ptr", data)
            logicalFontHeight := NumGet(data, 0, "Int") / view.Dpi.Scale
            for dpi in [96, 120, 144, 192, 240, actualDpi] {
                bounds := Buffer(16)
                NumPut("Int", Round(WindowInspectorView.Width * dpi / 96), "Int", Round(WindowInspectorView.Height * dpi / 96), bounds, 8)
                DllCall("AdjustWindowRectExForDpi", "Ptr", bounds, "UInt", WinGetStyle(view.Handle),
                    "Int", false, "UInt", WinGetExStyle(view.Handle), "UInt", actualDpi)
                width := NumGet(bounds, 8, "Int") - NumGet(bounds, 0, "Int")
                height := NumGet(bounds, 12, "Int") - NumGet(bounds, 4, "Int")
                NumPut("Int", 60, "Int", 60, "Int", 60 + width, "Int", 60 + height, bounds)
                SendMessage(GuiDpi.ChangedMessage, dpi | (dpi << 16), bounds.Ptr,, view.Handle)
                Sleep(30)
                this.Assert(view.Dpi.Scale == dpi / 96, "DPI notification updates view scale")
                this.ProcessLayout(view)
                for combo in [view.Priority, view.Search] {
                    combo.GetPos(,,, &closedHeight)
                    rowHeight := SendMessage(0x0154, 0, 0, combo) ; CB_GETITEMHEIGHT
                    this.Assert(GuiDpi.DropHeight(combo) >= closedHeight + 5 * rowHeight, "Dropdown retains multiple visible rows after resize and DPI change")
                }
                view.Finder.GetPos(&x, &y, &w, &h)
                this.Assert(x == view.Dpi.Px(8) && y == view.Dpi.Px(4) && w == view.Dpi.Px(34) && h == view.Dpi.Px(30),
                    "Finder bounds scale from original layout without accumulated rounding")
                font := SendMessage(GuiDpi.GetFontMessage, 0, 0, view.Status.Hwnd)
                DllCall("gdi32\GetObjectW", "Ptr", font, "Int", data.Size, "Ptr", data)
                this.Assert(Abs(NumGet(data, 0, "Int") - Round(logicalFontHeight * view.Dpi.Scale)) <= 1, "Native font scales with DPI")
                view.Info.GetPos(&leftX,, &leftW), view.ControlList.GetPos(&rightX,, &rightW)
                this.Assert(leftX + leftW < rightX && rightW > leftW, "DPI change preserves list layout")
            }
        } finally GuiDpi.Leave(previous)
    }
}

try {
    WindowInspectorTests.Run()
    ExitApp(0)
} catch Error as err {
    FileAppend(err.Message "`n" err.Stack "`n", "**")
    ExitApp(1)
}
