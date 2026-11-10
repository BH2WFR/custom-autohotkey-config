; 一次双指缩放手势及其生命周期；暂停、重置和退出均取消触点。
class TouchpadActions {
    static ZoomIn := 1
    static ZoomOut := -1
    static Steps := 6
    static FrameDelay := 10
    static SmallDistance := 100
    static LargeDistance := 250
    static DistanceChange := 120
    static EdgeMargin := 2

    __New(injection) {
        this.Injection := injection
        this.Enabled := true
        this.Busy := false
        this.Active := false
        this.Cancelled := false
        this.LastPoints := []
    }

    Zoom(direction, *) {
        if !this.Enabled || this.Busy
            return false
        this.Busy := true
        this.Cancelled := false
        try {
            position := this.Injection.Position()
            frames := TouchpadActions.Plan(position, direction)
            this.Injection.Initialize()
            try {
                if this.Cancelled
                    return false
                this.Frame(frames[1], TouchInjection.Down)
                loop TouchpadActions.Steps {
                    Sleep(TouchpadActions.FrameDelay)
                    if this.Cancelled
                        return false
                    this.Frame(frames[A_Index + 1], TouchInjection.Update)
                }
                Sleep(TouchpadActions.FrameDelay)
                if this.Cancelled
                    return false
                this.End(TouchInjection.Up)
                return true
            } finally {
                try this.End(TouchInjection.Cancel)
                finally this.Injection.Restore(position)
            }
        } finally this.Busy := false
    }

    Frame(points, flags) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.Injection.Send(points, flags)
            this.LastPoints := points
            this.Active := true
        } finally Critical(previousCritical)
    }

    End(flags) {
        if !this.Active
            return
        previousCritical := A_IsCritical
        Critical("On")
        try this.Injection.Send(this.LastPoints, flags)
        finally {
            this.Active := false
            Critical(previousCritical)
        }
    }

    ResetInput() {
        this.Cancelled := true
        this.End(TouchInjection.Cancel)
    }
    SetEnabled(enabled) {
        this.Enabled := !!enabled
        if !enabled
            this.ResetInput()
    }
    Stop() => this.SetEnabled(false)

    static Plan(position, direction) {
        if direction != this.ZoomIn && direction != this.ZoomOut
            throw ValueError("缩放方向必须为 ZoomIn 或 ZoomOut。")
        start := direction == this.ZoomIn ? this.SmallDistance : this.LargeDistance
        finish := start + direction * this.DistanceChange
        scale := Min(position.Scale, (position.Right - position.Left - 2 * this.EdgeMargin) / Max(start, finish))
        radius := Ceil(Max(start, finish) * scale / 2)
        x := Max(position.Left + radius + this.EdgeMargin, Min(position.Right - radius - this.EdgeMargin, position.X))
        y := Max(position.Top + this.EdgeMargin, Min(position.Bottom - this.EdgeMargin, position.Y))
        frames := []
        loop this.Steps + 1 {
            distance := (start + (finish - start) * (A_Index - 1) / this.Steps) * scale
            frames.Push([{X: Round(x - distance / 2), Y: y}, {X: Round(x + distance / 2), Y: y}])
        }
        return frames
    }
}
