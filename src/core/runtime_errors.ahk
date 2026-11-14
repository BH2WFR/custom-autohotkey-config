; 运行期未处理异常的统一提示；保留异常退栈和各模块的 finally 收尾。
class RuntimeErrors {
    static TipDuration := 2500

    __New(tooltip) {
        this.Tooltip := tooltip
        this.Callback := ObjBindMethod(this, "Handle")
    }

    Start() => OnError(this.Callback)
    Stop() => OnError(this.Callback, 0)

    Handle(err, mode) {
        ; 致命运行时错误仍交给 AHK 处理。
        if mode == "ExitApp" || !(err is Error)
            return 0
        this.Report(err)
        return 1
    }

    Report(err) {
        operation := err.What != "" ? err.What : "操作"
        this.Tooltip.Show(operation "失败：" err.Message, RuntimeErrors.TipDuration)
    }
}
