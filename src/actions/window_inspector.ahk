; 查看器目标与生命周期，系统查询和界面通过各自模块完成。
class WindowInspectorActions {
    static TipDuration := 800
    static ErrorDuration := 1800
    View := 0
    Data := 0

    __New(viewFactory, windows, tooltip) {
        this.ViewFactory := viewFactory
        this.Windows := windows
        this.Tooltip := tooltip
    }

    Open(context) {
        try this._Open(context)
        catch Error as err
            this.ReportError(err)
    }

    _Open(context) {
        if !this.View {
            commands := Map()
            for name in ["Close", "Search", "RefreshList", "Refresh", "Controls", "Priority",
                "Properties", "OpenPath", "Activate", "Center", "ResetSize", "CloseWindow", "Restart", "Terminate", "Copy", "PickAtCursor", "Pick"]
                commands[name] := ObjBindMethod(this, "Invoke", name)
            this.View := this.ViewFactory.Call(commands)
        }
        if context.Hwnd != this.View.Handle
            this.Invoke("Load", context.Hwnd)
        this.View.Show()
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
        this.View.SetTopmost(false)
        WinActivate(data.Hwnd)
    }

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
        if data.Pid == DllCall("GetCurrentProcessId", "UInt")
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
        if this.View
            this.View.Destroy()
        this.View := 0, this.Data := 0
    }
}
