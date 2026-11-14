; 热键运行状态；不依赖托盘或项目绑定表。
class HotkeySession {
    __New(tooltip, controllers*) {
        this.Controllers := controllers
        this.Tooltip := tooltip
        this.Paused := false
    }

    Toggle(*) => this.SetPaused(!this.Paused)
    IsPaused(*) => this.Paused

    ResetHooks(reinstall, *) {
        previousCritical := A_IsCritical
        paused := this.Paused
        Critical("On")
        try {
            this.SetPaused(true)
            for controller in this.Controllers
                controller.ResetInput()
            reinstall.Call()
        } finally {
            try this.SetPaused(paused)
            finally Critical(previousCritical)
        }
    }

    SetPaused(paused) {
        this.Paused := !!paused
        this.Tooltip.Hide()
        for controller in this.Controllers {
            try controller.SetEnabled(!paused)
            catch Error as err {
                if !IsSet(failure)
                    failure := err
            }
        }
        if IsSet(failure)
            throw failure
    }
}
