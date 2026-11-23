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
            for name in ["Close", "Search", "RefreshList", "Refresh", "Controls", "Priority",
                "Properties", "OpenPath", "Activate", "ShowBorder", "Center", "ResetSize", "CloseWindow", "Restart", "Terminate", "Copy", "PickAtCursor", "Pick"]
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
        this.Tooltip.Show("窗口操作失败：" err.Message, WindowInspectorActions.ErrorDuration)
    }

    Load(hwnd) {
        data := WindowInfo.Read(hwnd)
        this.Data := data
        this.View.Render(data)
        this.Details(data)
    }

    Target() {
        if !this.Data
            throw TargetError("请先选择窗口。")
        data := WindowInfo.Read(this.Data.Hwnd)
        if data.Pid != this.Data.Pid
            throw TargetError("原窗口已关闭，请重新查找。")
        return data
    }

    Search(query, hidden) {
        hwnd := WindowInfo.Find(query, hidden)
        if !hwnd
            throw TargetError("未找到匹配窗口。")
        this.Load(hwnd)
    }

    RefreshList(hidden) => this.View.SetWindows(WindowInfo.List(hidden, this.View.Handle))
    PickAtCursor() => WindowInfo.AtCursor()
    Pick(hwnd) {
        this.Load(hwnd)
        this.View.Show()
    }
    Refresh() => this.Load(this.Target().Hwnd)
    Details(data) {
        this.View.RenderDetails(ProcessTools.Read(data.Pid), ProcessTools.FileInfo(data.Path))
    }
    Controls() => this.View.RenderControls(WindowInfo.Controls(this.Target().Hwnd))

    Copy(text) {
        A_Clipboard := text
        this.Tooltip.Show("已复制", WindowInspectorActions.TipDuration)
    }

    Priority(priority) {
        ProcessTools.SetPriority(this.Target().Pid, priority)
        this.Details(this.Target())
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
            if WinGetMinMax(data.Hwnd) == -1
                WinRestore(data.Hwnd)
            WinActivate(data.Hwnd)
            if !WinActive(data.Hwnd)
                throw TargetError("无法将目标窗口移到前台。")
            this.View.Highlight(data.Hwnd, WindowInspectorActions.PreviewMs)
        } catch as err {
            this.View.Show()
            throw err
        }
        SetTimer(this.ReturnTimer, -WindowInspectorActions.PreviewMs)
        name := data.Title != "" ? data.Title : data.ProcessName
        this.Tooltip.Show("已将窗口「" name "」移动到前台，" WindowInspectorActions.PreviewSeconds " 秒后将焦点切回窗口信息查看器。", WindowInspectorActions.PreviewMs)
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

    CloseWindow() {
        data := this.Target()
        if !this.View.Confirm("关闭窗口？`n" data.Title)
            return
        WinClose(this.Target().Hwnd)
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
        data := this.Target()
        if restart
            ProcessTools.Restart(data.Pid, data.Path)
        else
            ProcessTools.Terminate(data.Pid)
        this.Data := 0
        this.View.SetStatus("已" verb "进程；可查找新窗口")
    }

    Close() {
        SetTimer(this.ReturnTimer, 0)
        if this.View
            this.View.Destroy()
        this.View := 0, this.Data := 0
    }
}
