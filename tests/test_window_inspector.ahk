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

class WindowInspectorTests {
    static Count := 0
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
            b := WindowGeometry.Measure(popup.Hwnd)
            if !DllCall("SetPhysicalCursorPos", "Int", b.X + 40, "Int", b.Y + 40) {
                FileAppend("SKIP pointer hit-test: input desktop unavailable`n", "*")
                return
            }
            this.Assert(WindowInfo.AtCursor() == popup.Hwnd, "Physical hit-test keeps owned popup instead of its owner")
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
            this.Assert(view.Info.GetCount() == 25 && InStr(view.Fields["命令行"].Value, "test_window_inspector.ahk"), "Picked popup immediately loads process details")
            for edge in view.Picker.Border.Edges
                this.Assert(!DllCall("IsWindowVisible", "Ptr", edge.Hwnd), "Release hides highlight edge")
        } finally {
            view.Picker.Cancel()
            DllCall("SetPhysicalCursorPos", "Int", NumGet(point, 0, "Int"), "Int", NumGet(point, 4, "Int"))
            popup.Destroy()
        }
    }
    static Run() {
        target := Gui(, "Inspector test 中文窗口"), other := Gui(, "Inspector second window")
        edit := target.AddEdit("w300", "控件内容 test")
        target.AddButton(, "测试按钮")
        target.Show("x100 y100 w400 h200 NA")
        tip := this.Tip(), actions := WindowInspectorActions(WindowInspectorView, WindowActions(tip), tip)
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
            this.Assert(InStr(process.CommandLine, "test_window_inspector.ahk") && process.Architecture == "x64", "Actual WMI command line and process architecture")
            this.Assert(process.User != "" && process.Priority != "" && process.WorkingSet > 0, "Process owner, priority and memory")
            this.Assert(ProcessTools.FileInfo(data.Path).Version != "", "Executable file version")
            actions.Open({Hwnd: target.Hwnd})
            view := actions.View, handle := view.Handle
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
            this.Assert(view.Info.GetCount() == 25 && InStr(view.Fields["命令行"].Value, "test_window_inspector.ahk"), "Opening immediately loads process details")
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
            this.Assert(view.Info.GetCount() == 25 && view.ControlList.GetCount() == 2, "Native lists show basic, process and control data")
            actions.Refresh()
            this.Assert(view.Info.GetCount() == 25 && InStr(view.Fields["命令行"].Value, "test_window_inspector.ahk"), "Refresh automatically replaces process details")
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
            bounds := WindowGeometry.Measure(target.Hwnd), edge := WindowGeometry.Measure(border.Edges[1].Hwnd)
            thickness := Round(WindowHighlightView.Thickness * bounds.Scale)
            this.Assert(edge.X == bounds.X - thickness && edge.Y == bounds.Y - thickness
                && edge.Width == bounds.Width + 2 * thickness && edge.Height == thickness, "Highlight follows physical coordinates and monitor scale")
            this.Assert((WinGetExStyle(border.Edges[1].Hwnd) & 0x08080020) == 0x08080020, "Highlight is layered, click-through and non-activating")
            border.Hide()
            view.Picker.Message(0, 0, WindowPickerView.MouseDown, view.Finder.Hwnd)
            this.Assert(view.Picker.Dragging && DllCall("GetCapture", "Ptr") == handle, "Finder captures drag outside its control")
            view.Escape()
            this.Assert(!view.Picker.Dragging && !DllCall("GetCapture", "Ptr"), "Escape cancels capture without closing viewer")
            this.PickerTest(view, actions, target)
            actions.Load(target.Hwnd)
            view.Gui.Show("w1200 h750 NA")
            Sleep(100)
            view.Info.GetPos(&leftX,, &leftW), view.ControlList.GetPos(&rightX,, &rightW)
            this.Assert(leftX + leftW < rightX && rightW > leftW, "Resized lists retain gap and proportions")
            this.DpiTest(view)
            closedHwnd := other.Hwnd
            other.Destroy()
            actions.Invoke("Load", closedHwnd)
            this.Assert(view.Status.Text != "" && actions.Data.Hwnd == target.Hwnd, "Closed target reports error without replacing snapshot")
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
