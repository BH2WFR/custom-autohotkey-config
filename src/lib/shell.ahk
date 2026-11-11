; Windows Shell 基础能力，不包含项目菜单。
class ShellTools {
    static GuidSize := 16
    static Explorer := A_WinDir "\explorer.exe"
    static FileInfoSize := A_PtrSize + 688
    static IconFlags := 0x100 | 0x8 | 0x1 ; SHGFI_ICON | SHGFI_PIDL | SHGFI_SMALLICON

    ; 返回由调用方 DestroyIcon 释放的图标句柄，支持文件及 Shell 应用命名空间。
    static Icon(path) {
        pidl := 0
        if DllCall("shell32\SHParseDisplayName", "Str", path, "Ptr", 0,
            "Ptr*", &pidl, "UInt", 0, "Ptr", 0, "Int") < 0
            return 0
        try {
            info := Buffer(this.FileInfoSize, 0)
            if !DllCall("shell32\SHGetFileInfoW", "Ptr", pidl, "UInt", 0,
                "Ptr", info, "UInt", info.Size, "UInt", this.IconFlags, "UPtr")
                return 0
            return NumGet(info, 0, "Ptr")
        } finally DllCall("ole32\CoTaskMemFree", "Ptr", pidl)
    }

    static KnownFolder(id) {
        guid := Buffer(this.GuidSize), path := 0
        DllCall("ole32\CLSIDFromString", "Str", id, "Ptr", guid, "HRESULT")
        DllCall("shell32\SHGetKnownFolderPath", "Ptr", guid, "UInt", 0, "Ptr", 0, "Ptr*", &path, "HRESULT")
        try return StrGet(path, "UTF-16")
        finally DllCall("ole32\CoTaskMemFree", "Ptr", path)
    }

    static Open(target, folder := false) {
        if folder {
            if target == ""
                throw ValueError("路径为空。")
            Run('"' this.Explorer '" "' target '"')
        } else
            Run(target)
    }

    static Properties(path) => Run('properties "' path '"')

    static SelectFile(path) => Run('"' this.Explorer '" /select,"' path '"')
}
