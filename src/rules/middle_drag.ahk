; 中键拖动的应用策略；窗口名单统一维护于 WindowGroups。
class MiddleDragPolicy {
    static Left := ["LButton"]
    static SpaceLeft := ["Space", "LButton"]
    static None := []

    static Resolve(hwnd) {
        if WindowGroups.Matches(WindowGroups.MiddleDragSpaceLeft, hwnd)
            return this.SpaceLeft
        if WindowGroups.Matches(WindowGroups.MiddleDragLeft, hwnd)
            return this.Left
        return this.None
    }
}
