; 按 PID 查询和操作进程，不包含界面与项目策略。
class ProcessTools {
    static QueryAccess := 0x1000
    static TokenQuery := 0x0008
    static TokenElevation := 20
    static Priorities := Map(0x40, "Low", 0x4000, "BelowNormal", 0x20, "Normal",
        0x8000, "AboveNormal", 0x80, "High", 0x100, "Realtime")
    static Machines := Map(0x014C, "x86", 0x8664, "x64", 0xAA64, "ARM64")
    static StopTimeout := 3

    static Read(pid) {
        query := "SELECT ProcessId, CommandLine, CreationDate, WorkingSetSize, VirtualSize FROM Win32_Process WHERE ProcessId=" Integer(pid)
        for process in ComObjGet("winmgmts:").ExecQuery(query) {
            data := {CommandLine: process.CommandLine, Created: SubStr(process.CreationDate, 1, 14),
                WorkingSet: process.WorkingSetSize, VirtualSize: process.VirtualSize,
                User: "", Elevated: "", Architecture: "", Priority: ""}
            try {
                owner := process.ExecMethod_("GetOwner")
                if owner.ReturnValue == 0
                    data.User := owner.Domain "\" owner.User
            }
            handle := DllCall("OpenProcess", "UInt", this.QueryAccess, "Int", false, "UInt", pid, "Ptr")
            if !handle
                throw OSError()
            try {
                data.Priority := this.Priorities.Get(DllCall("GetPriorityClass", "Ptr", handle, "UInt"), "")
                processMachine := 0, nativeMachine := 0
                if DllCall("IsWow64Process2", "Ptr", handle, "UShort*", &processMachine, "UShort*", &nativeMachine)
                    data.Architecture := this.Machines.Get(processMachine ? processMachine : nativeMachine, "")
                token := 0
                if DllCall("advapi32\OpenProcessToken", "Ptr", handle, "UInt", this.TokenQuery, "Ptr*", &token) {
                    try {
                        elevated := 0, size := 0
                        if DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", this.TokenElevation,
                            "UInt*", &elevated, "UInt", 4, "UInt*", &size)
                            data.Elevated := elevated ? "是" : "否"
                    } finally DllCall("CloseHandle", "Ptr", token)
                }
            } finally DllCall("CloseHandle", "Ptr", handle)
            return data
        }
        throw TargetError("进程已退出。")
    }

    static FileInfo(path) {
        data := {Version: "", Modified: "", Created: ""}
        if path != "" {
            try data.Version := FileGetVersion(path)
            try data.Modified := FileGetTime(path, "M")
            try data.Created := FileGetTime(path, "C")
        }
        return data
    }

    static SetPriority(pid, priority) {
        if !ProcessSetPriority(priority, pid)
            throw Error("无法设置进程优先级。")
    }

    static Terminate(pid) {
        if !ProcessClose(pid)
            throw Error("无法终止进程。")
        if ProcessWaitClose(pid, this.StopTimeout)
            throw Error("进程尚未退出。")
    }

    static Restart(pid, path) {
        if !FileExist(path)
            throw Error("找不到进程文件：" path)
        this.Terminate(pid)
        SplitPath(path,, &directory)
        Run('"' path '"', directory,, &newPid)
        return newPid
    }
}
