; 查看器目标与生命周期，系统查询和界面通过各自模块完成。
class WindowInspectorActions {
    static TipDuration := 800
    static ErrorDuration := 1800
    static PreviewSeconds := 3
    static PreviewMs := WindowInspectorActions.PreviewSeconds * 1000
    View := 0
    Data := 0

    __New(viewFactory, windows, tooltip, hostPid := 0) {
        this.ViewFactory := viewFactory
        this.Windows := windows
        this.Tooltip := tooltip
        this.HostPid := hostPid
        this.ReturnTimer := ObjBindMethod(this, "Invoke", "ReturnFocus")
    }

    Open(context) {
        try this._Open(context)
        catch Error as err
            this.ReportError(err)
    }

    _Open(context) {
        SetTimer(this.ReturnTimer, 0)
        if !this.View {
            commands := Map()
            for name in ["Close", "Search", "Select", "RefreshList", "RefreshInfo", "Controls", "Priority",
                "Properties", "OpenPath", "Activate", "ShowBorder", "Center", "ResetSize", "ToggleTopmost", "ToggleClickThrough", "SetOpacity", "Minimize",
                "CloseWindow", "Restart", "Terminate", "Copy", "PickAtCursor", "Pick"]
                commands[name] := ObjBindMethod(this, "Invoke", name)
            this.View := this.ViewFactory.Call(commands)
        }
        this.View.Show()
        if context.Hwnd != this.View.Handle
            this.Invoke("Load", context.Hwnd)
    }

    Invoke(method, args*) {
        try return this.%method%(args*)
        catch Error as err {
            this.ReportError(err)
            return false
        }
    }

    ReportError(err) {
        if this.View
            try this.View.SetStatus(err.Message)
        this.Tooltip.Show("窗口操作失败：`n" err.Message, WindowInspectorActions.ErrorDuration)
    }

    ReadTarget(hwnd, pid := 0) {
        try {
            data := WindowInfo.Read(hwnd)
            if pid && data.Pid != pid
                throw TargetError("原窗口已关闭，请重新选择。")
            return data
        } catch as err {
            this.ClearTarget()
            throw err
        }
    }

    ClearTarget(keepQuery := false) {
        this.Data := 0
        this.View.ClearTarget(keepQuery)
    }

    Select(entry) {
        if entry
            this.Load(entry.Hwnd, entry.Pid)
        else
            this.ClearTarget(true)
    }

    Load(hwnd, pid := 0) {
        data := this.ReadTarget(hwnd, pid)
        this.Display(data)
    }

    Target() {
        entry := this.View.SelectedEntry
        if !entry || !this.Data || entry.Hwnd != this.Data.Hwnd || entry.Pid != this.Data.Pid
            throw TargetError("请先选择窗口。")
        return this.ReadTarget(entry.Hwnd, entry.Pid)
    }

    Search(query, hidden) {
        hwnd := WindowInfo.Find(query, hidden)
        if !hwnd {
            this.ClearTarget()
            throw TargetError("未找到匹配窗口。")
        }
        this.Load(hwnd)
    }

    RefreshList(hidden) {
        entries := WindowInfo.List(hidden, this.View.Handle)
        count := entries.Length
        this.View.SetWindows(entries)
        if this.Data && this.View.SelectWindow(this.Data, false)
            this.Refresh()
        else
            this.ClearTarget()
        this.Tip("列表已刷新，共 " count " 个窗口")
    }
    PickAtCursor() => WindowInfo.AtCursor()
    Pick(hwnd) {
        this.Load(hwnd)
        this.View.Show()
    }
    Refresh() => this.Display(this.Target())

    RefreshInfo() {
        this.Refresh()
        this.Tip("窗口信息已刷新")
    }

    Tip(text) => this.Tooltip.Show(text, WindowInspectorActions.TipDuration)

    Display(data) {
        this.Data := data
        this.View.Render(data)
        this.Details(data)
    }
    Details(data) {
        process := ProcessTools.Read(data.Pid), file := ProcessTools.FileInfo(data.Path)
        if this.Data == data
            this.View.RenderDetails(process, file)
    }
    Controls() {
        target := this.Target(), snapshot := this.Data
        controls := WindowInfo.Controls(target.Hwnd)
        if this.Data == snapshot {
            this.View.RenderControls(controls)
            this.Tip("已读取 " controls.Length " 个控件")
        }
    }

    Copy(text) {
        A_Clipboard := text
        this.Tip("已复制")
    }

    Priority(priority) {
        ProcessTools.SetPriority(this.Target().Pid, priority)
        this.Details(this.Data)
        this.Tip("进程优先级已设为 " priority)
    }

    Properties() {
        ShellTools.Properties(this.Target().Path)
        this.View.SetTopmost(false)
    }

    OpenPath() {
        ShellTools.SelectFile(this.Target().Path)
        this.View.SetTopmost(false)
    }

    Activate() {
        data := this.Target()
        SetTimer(this.ReturnTimer, 0)
        this.View.SuspendTopmost()
        try {
            if !data.Visible
                WinShow(data.Hwnd)
            minimized := WinGetMinMax(data.Hwnd) == -1
            if minimized
                WinRestore(data.Hwnd)
            WinActivate(data.Hwnd)
            if !WinActive(data.Hwnd)
                throw TargetError("无法将目标窗口移到前台。")
            if minimized || !data.Visible
                this.Refresh()
            this.View.Highlight(data.Hwnd, WindowInspectorActions.PreviewMs)
        } catch as err {
            this.View.Show()
            throw err
        }
        SetTimer(this.ReturnTimer, -WindowInspectorActions.PreviewMs)
        this.Tooltip.Show("窗口已激活`n" WindowInspectorActions.PreviewSeconds " 秒后切回窗口信息查看器", WindowInspectorActions.PreviewMs)
    }

    ShowBorder() {
        try this.View.Highlight(this.Target().Hwnd, WindowInspectorActions.PreviewMs)
        catch as err
            this.View.Warn("无法显示窗口边界：" err.Message)
    }

    ReturnFocus() => this.View.Show()

    Center() => this.Resize(false)
    ResetSize() => this.Resize(true)
    Resize(reset) {
        if this.Windows.Center(reset, this.Target())
            this.Refresh()
    }

    ToggleTopmost() {
        target := this.Target()
        this.Windows.ToggleTopmost(target)
        this.RefreshWindowState(target.Hwnd)
    }

    RefreshWindowState(hwnd) {
        if this.Data && this.Data.Hwnd == hwnd {
            this.Data := this.Target()
            this.View.RenderBasic(this.Data)
        }
    }

    ToggleClickThrough() {
        target := this.Target()
        try {
            if !target.LayeredClickThrough && !this.Windows.CanAdjust(target.Hwnd)
                return
            WindowTools.PassThrough(target.Hwnd, !target.LayeredClickThrough, this.Windows.PassOpacity)
        } finally this.RefreshWindowState(target.Hwnd)
        if this.Data && this.Data.Hwnd == target.Hwnd
            this.Tip(this.Data.LayeredClickThrough ? "已开启窗口穿透" : "已关闭窗口穿透")
    }

    SetOpacity(percent) {
        target := this.Target()
        if !IsInteger(percent) || percent < 0 || percent > 100
            throw ValueError("请输入 0 到 100 之间的整数。")
        if !this.Windows.CanAdjust(target.Hwnd) {
            this.RefreshWindowState(target.Hwnd)
            return
        }
        WindowTools.SetOpacity(target.Hwnd, Round(percent * WindowTools.Opaque / 100))
        this.RefreshWindowState(target.Hwnd)
        this.Tip("不透明度已设为 " percent "%")
    }

    Minimize() {
        target := this.Target()
        if target.Visible {
            if !this.Windows.CanAdjust(target.Hwnd)
                return
            WindowTools.MinimizeOrHide(target.Hwnd)
            this.Refresh()
        }
        this.Tip("窗口状态：" (target.Visible ? this.Data.State : target.State))
    }

    CloseWindow() {
        data := this.Target()
        if !this.View.Confirm("关闭窗口？`n" data.Title)
            return
        if !this.ConfirmedTarget(data)
            return
        WinClose(data.Hwnd)
        if !DllCall("IsWindow", "Ptr", data.Hwnd)
            this.ClearTarget()
        this.View.SetStatus("已发送关闭窗口请求")
    }

    Restart() => this.ProcessAction(true)
    Terminate() => this.ProcessAction(false)
    ProcessAction(restart) {
        data := this.Target()
        if data.Pid == ProcessExist() || data.Pid == this.HostPid
            throw Error("请通过托盘重载或退出本工具。")
        verb := restart ? "重启" : "终止"
        if !this.View.Confirm(verb "进程？未保存的内容将丢失。`n" data.ProcessName " (PID " data.Pid ")")
            return
        if !this.ConfirmedTarget(data)
            return
        if restart
            ProcessTools.Restart(data.Pid, data.Path)
        else
            ProcessTools.Terminate(data.Pid)
        this.ClearTarget()
        this.View.SetStatus("已" verb "进程；可查找新窗口")
    }

    ConfirmedTarget(expected) {
        current := this.Target()
        return current.Hwnd == expected.Hwnd && current.Pid == expected.Pid
    }

    Close() {
        SetTimer(this.ReturnTimer, 0)
        if this.View
            this.View.Destroy()
        this.View := 0, this.Data := 0
    }
}
