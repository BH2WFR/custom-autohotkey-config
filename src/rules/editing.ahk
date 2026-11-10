; 应用策略由规则层提供，基础编辑模块不识别应用。
class EditingPolicy {
    static Keys(hwnd) => WindowGroups.Matches(WindowGroups.FileManager, hwnd)
        ? {Copy: "^c", Cut: "^x", Paste: "^v"}
        : {Copy: ClipboardService.CopyKey, Cut: ClipboardService.CutKey, Paste: ClipboardService.PasteKey}
    static CanEditLine(hwnd) => !WindowGroups.Matches(WindowGroups.FileManager, hwnd)
    static AltEnter(hwnd) => WindowGroups.Matches(WindowGroups.AltEnter, hwnd)
}
