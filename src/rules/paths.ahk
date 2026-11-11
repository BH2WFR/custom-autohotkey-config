; 沿用旧版 OpenMenuForPaths 的条目、顺序和启动命令。
class PathMenuBindings {
    static ShellIcons := A_WinDir "\System32\shell32.dll"
    static ImageIcons := A_WinDir "\System32\imageres.dll"
    static SystemDirectory := A_WinDir "\System32\"
    static FolderIconIndex := 4
    static PackagedIcons := Map("画图", "shell:AppsFolder\Microsoft.Paint_8wekyb3d8bbwe!App")
    ; MSC 图标沿用系统控制台声明；其他工具使用对应程序或控制面板模块的图标。
    static CommandIcons := Map(
        "网络连接", [PathMenuBindings.ShellIcons, -193],
        "磁盘管理", [PathMenuBindings.SystemDirectory "dmdskres.dll", 1],
        "系统属性", [PathMenuBindings.SystemDirectory "sysdm.cpl", 1],
        "证书管理器(当前用户)", [A_WinDir "\System32\certmgr.dll", -218],
        "证书管理器(本地计算机)", [A_WinDir "\System32\certmgr.dll", -379],
        "计算机管理", [PathMenuBindings.SystemDirectory "mycomput.dll", 3],
        "系统配置", [PathMenuBindings.SystemDirectory "msconfig.exe", 1],
        "电源选项", [A_WinDir "\System32\powercfg.cpl", -202],
        "程序和功能", [PathMenuBindings.SystemDirectory "appwiz.cpl", 1],
        "用户账户", [PathMenuBindings.SystemDirectory "netplwiz.exe", 1],
        "防火墙", [PathMenuBindings.SystemDirectory "authfwgp.dll", 1],
        "环境变量", [PathMenuBindings.SystemDirectory "sysdm.cpl", 1],
        "注册表编辑器", [A_WinDir "\regedit.exe", -100],
        "组策略编辑器", [PathMenuBindings.SystemDirectory "gpedit.dll", 1],
        "服务", [PathMenuBindings.SystemDirectory "filemgmt.dll", 1],
        "事件查看器", [PathMenuBindings.SystemDirectory "miguiresource.dll", 1],
        "任务管理器", [A_WinDir "\System32\Taskmgr.exe", 1],
        "性能监视器", [PathMenuBindings.SystemDirectory "wdc.dll", 1],
        "资源监视器", [PathMenuBindings.SystemDirectory "resmon.exe", 1],
        "设备管理器", [PathMenuBindings.SystemDirectory "devmgr.dll", 5],
        "计算器", [PathMenuBindings.SystemDirectory "calc.exe", 1],
        "画图", [PathMenuBindings.SystemDirectory "mspaint.exe", 1],
        "记事本", [PathMenuBindings.SystemDirectory "notepad.exe", 1],
        "字符映射表", [PathMenuBindings.SystemDirectory "charmap.exe", 1],
        "远程桌面连接", [A_WinDir "\System32\mstsc.exe", -101])
    static KnownFolders := Map(
        "Downloads", "{374DE290-123F-4565-9164-39C4925E467B}",
        "Pictures", "{33E28130-4E1E-4676-835A-98395C3BC3BB}",
        "Music", "{4BD8D571-6D19-48D3-BE97-422220080E43}",
        "Videos", "{18989B1D-99B5-455B-841C-AB7C74E4DDFC}",
        "OneDrive", "{A52BBA46-E9E1-435F-B3D9-28DAA648C0F6}")

    static Item(name, target, folder := false, label := "", icon := "", index := 1) {
        item := {Name: name, Label: label == "" ? name : label, Target: target, Folder: folder}
        if icon == "" && this.CommandIcons.Has(name)
            icon := this.CommandIcons[name][1], index := this.CommandIcons[name][2]
        if icon == "" && folder && DirExist(target)
            icon := this.ShellIcons, index := this.FolderIconIndex
        if icon != "" && FileExist(icon)
            item.Icon := icon, item.IconIndex := index
        else if this.PackagedIcons.Has(name)
            item.ShellIcon := this.PackagedIcons[name]
        return item
    }
    static Folder(name, path, expanded := false, icon := "", index := 1) =>
        this.Item(name, path, true, expanded ? "(" name ") " path : name, icon, index)
    static Group(label, items, icon, index) => {Label: label, Items: items, Icon: icon, IconIndex: index}

    static Create(root) {
        shell := this.ShellIcons, image := this.ImageIcons
        folders := Map()
        for name, id in this.KnownFolders {
            if name != "OneDrive"
                folders[name] := ShellTools.KnownFolder(id)
        }
        oneDrive := ""
        for variable in ["OneDrive", "OneDriveConsumer", "OneDriveCommercial"] {
            oneDrive := EnvGet(variable)
            if oneDrive != ""
                break
        }
        if oneDrive == ""
            oneDrive := ShellTools.KnownFolder(this.KnownFolders["OneDrive"])
        appData := this.Folder("AppData", A_AppData, true, image, -198)
        home := this.Folder("HomePath", EnvGet("HOMEDRIVE") EnvGet("HOMEPATH"), true, image, 84)
        drive := this.Folder("SystemDrive", EnvGet("SystemDrive") "\", true, shell, 8)
        paths := [this.Folder("桌面", A_Desktop, false, image, 175),
            this.Folder("下载", folders["Downloads"], false, image, -184),
            this.Folder("文档", A_MyDocuments, false, shell, -235),
            this.Folder("图片", folders["Pictures"], false, shell, -236),
            this.Folder("OneDrive", oneDrive, false, image, -1043),
            this.Folder("Music", folders["Music"], true, shell, -237),
            this.Folder("Videos", folders["Videos"], true, shell, -238), "",
            appData, this.Folder("LocalAppData", EnvGet("LOCALAPPDATA"), true),
            this.Folder("ProgramData", A_AppDataCommon, true), this.Folder("UserProfile", EnvGet("USERPROFILE"), true),
            home, this.Folder("ProgramFiles", A_ProgramFiles, true),
            this.Folder("ProgramFiles(x86)", EnvGet("ProgramFiles(x86)"), true), drive,
            this.Folder("WinDir", A_WinDir, true, shell, -177), this.Folder("Temp", A_Temp, true), "",
            this.Folder("开始菜单", A_StartMenu), this.Folder("启动项", A_Startup),
            this.Folder("网络", "shell:NetworkPlacesFolder", false, shell, -176)]
        settings := [this.Item("控制面板", "control.exe", false,, shell, 22),
            this.Folder("上帝模式 (God Mode)", "shell:::{ED7BA470-8E54-465E-825C-99712043E01C}", false, shell, -183), ""]
        for entry in [["网络连接", "ncpa.cpl"], ["磁盘管理", "diskmgmt.msc"], ["系统属性", "sysdm.cpl"],
            ["证书管理器(当前用户)", "certmgr.msc"], ["证书管理器(本地计算机)", "certlm.msc"],
            ["计算机管理", "compmgmt.msc"], ["系统配置", "msconfig.exe"], ["电源选项", "powercfg.cpl"],
            ["程序和功能", "appwiz.cpl"], ["用户账户", "netplwiz.exe"], ["防火墙", "wf.msc"],
            ["环境变量", "rundll32.exe sysdm.cpl,EditEnvironmentVariables"]]
            settings.Push(this.Item(entry[1], entry[2]))
        tools := []
        for entry in [["注册表编辑器", "regedit.exe"], ["组策略编辑器", "gpedit.msc"], ["服务", "services.msc"],
            ["事件查看器", "eventvwr.msc"], [], ["任务管理器", "taskmgr.exe"], ["性能监视器", "perfmon.msc"],
            ["资源监视器", "resmon.exe"], ["设备管理器", "devmgmt.msc"], [], ["计算器", "calc.exe"],
            ["画图", "mspaint.exe"], ["记事本", "notepad.exe"], ["远程桌面连接", "mstsc.exe"], ["字符映射表", "charmap.exe"]]
            tools.Push(entry.Length ? this.Item(entry[1], entry[2]) : "")
        title := this.Item("快捷路径和系统工具", "", false,, root "\res\MainIcon.ico")
        title.Disabled := true
        return [title, "", this.Item("资源管理器", ShellTools.Explorer, false,, ShellTools.Explorer),
            this.Folder("回收站", "shell:::{645FF040-5081-101B-9F08-00AA002F954E}", false, shell, 32),
            appData, home, drive, "", this.Group("常用路径", paths, shell, 4),
            this.Group("系统设置", settings, shell, 22), this.Group("其他工具", tools, shell, -16826), "",
            this.Item("退出菜单", "")]
    }
}
