; 按 PID 查询和操作进程，不包含界面与项目策略。
class ProcessTools {
    static QueryAccess := 0x1000
    static TokenQuery := 0x0008
    static TokenElevation := 20
    static Priorities := Map(0x40, "Low", 0x4000, "BelowNormal", 0x20, "Normal",
        0x8000, "AboveNormal", 0x80, "High", 0x100, "Realtime")
    static Machines := Map(0x014C, "x86", 0x8664, "x64", 0xAA64, "ARM64")
    static StopTimeout := 3

    static CommandLineInformation := 60
    static VmCounters := 3
    static TokenUser := 1

    static Read(pid) {
        handle := DllCall("OpenProcess", "UInt", this.QueryAccess, "Int", false, "UInt", pid, "Ptr")
        if !handle
            throw OSError()
        try {
            data := {CommandLine: this.CommandLine(handle), Created: this.Created(handle),
                WorkingSet: "", VirtualSize: "", User: "", Elevated: "", Architecture: "",
                Priority: this.Priorities.Get(DllCall("GetPriorityClass", "Ptr", handle, "UInt"), "")}
            ; VM_COUNTERS 字段使用调用方指针宽度，VirtualSize 为虚拟地址空间大小。
            counters := Buffer(11 * A_PtrSize)
            if DllCall("ntdll\NtQueryInformationProcess", "Ptr", handle, "Int", this.VmCounters,
                "Ptr", counters, "UInt", counters.Size, "Ptr", 0, "Int") >= 0 {
                data.VirtualSize := NumGet(counters, A_PtrSize, "UPtr")
                data.WorkingSet := NumGet(counters, 4 * A_PtrSize, "UPtr")
            }
            if DllCall("IsWow64Process2", "Ptr", handle, "UShort*", &machine := 0, "UShort*", &native := 0)
                data.Architecture := this.Machines.Get(machine ? machine : native, "")
            if DllCall("advapi32\OpenProcessToken", "Ptr", handle, "UInt", this.TokenQuery, "Ptr*", &token := 0) {
                try {
                    data.User := this.Account(token)
                    if DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", this.TokenElevation,
                        "UInt*", &elevated := 0, "UInt", 4, "UInt*", &size := 0)
                        data.Elevated := elevated ? "是" : "否"
                } finally DllCall("CloseHandle", "Ptr", token)
            }
            return data
        } finally DllCall("CloseHandle", "Ptr", handle)
    }

    static CommandLine(handle) {
        DllCall("ntdll\NtQueryInformationProcess", "Ptr", handle, "Int", this.CommandLineInformation,
            "Ptr", 0, "UInt", 0, "UInt*", &size := 0)
        if !size
            return ""
        info := Buffer(size)
        if DllCall("ntdll\NtQueryInformationProcess", "Ptr", handle, "Int", this.CommandLineInformation,
            "Ptr", info, "UInt", size, "Ptr", 0, "Int") < 0
            return ""
        length := NumGet(info, 0, "UShort") // 2
        return length ? StrGet(NumGet(info, A_PtrSize, "Ptr"), length, "UTF-16") : ""
    }

    static Created(handle) {
        if !DllCall("GetProcessTimes", "Ptr", handle, "Int64*", &created := 0, "Int64*", &ended := 0,
            "Int64*", &kernel := 0, "Int64*", &user := 0)
            return ""
        utc := Buffer(16), localTime := Buffer(16)
        if !DllCall("FileTimeToSystemTime", "Int64*", &created, "Ptr", utc)
            || !DllCall("SystemTimeToTzSpecificLocalTime", "Ptr", 0, "Ptr", utc, "Ptr", localTime)
            return ""
        return Format("{:04}{:02}{:02}{:02}{:02}{:02}", NumGet(localTime, 0, "UShort"), NumGet(localTime, 2, "UShort"),
            NumGet(localTime, 6, "UShort"), NumGet(localTime, 8, "UShort"), NumGet(localTime, 10, "UShort"), NumGet(localTime, 12, "UShort"))
    }

    static Account(token) {
        DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", this.TokenUser, "Ptr", 0, "UInt", 0, "UInt*", &size := 0)
        if !size
            return ""
        user := Buffer(size)
        if !DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", this.TokenUser, "Ptr", user, "UInt", size, "UInt*", &size)
            return ""
        sid := NumGet(user, 0, "Ptr")
        DllCall("advapi32\LookupAccountSidW", "Ptr", 0, "Ptr", sid, "Ptr", 0, "UInt*", &nameChars := 0,
            "Ptr", 0, "UInt*", &domainChars := 0, "UInt*", &use := 0)
        if !nameChars
            return ""
        name := Buffer(2 * nameChars), domain := Buffer(2 * Max(1, domainChars), 0)
        if !DllCall("advapi32\LookupAccountSidW", "Ptr", 0, "Ptr", sid, "Ptr", name, "UInt*", &nameChars,
            "Ptr", domain, "UInt*", &domainChars, "UInt*", &use)
            return ""
        return (domainChars ? StrGet(domain) "\" : "") StrGet(name)
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
