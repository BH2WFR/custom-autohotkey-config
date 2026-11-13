; 项目前台窗口分类；新增应用匹配项只修改此处。
class WindowGroups {
    static RemoteDesktop := "RemoteDesktop"
    static VirtualMachine := "VirtualMachine"
    static XButtonPassthrough := "XButtonPassthrough"
    static Anki := "Anki"
    static AnkiEditor := "AnkiEditor"
    static ImageViewer := "ImageViewer"
    static ChatImageViewer := "ChatImageViewer"
    static MiddleDragLeft := "MiddleDragLeft"
    static MiddleDragSpaceLeft := "MiddleDragSpaceLeft"
    static NavigationNative := "NavigationNative"
    static NavigationAltShift := "NavigationAltShift"
    static NavigationBackspace := "NavigationBackspace"
    static Cad := "Cad"
    static CajViewer := "CajViewer"
    static PowerIso := "PowerIso"
    static SiYuan := "SiYuan"
    static Explorer := "Explorer"
    static FileManager := "FileManager"
    static FolderUpAlt := "FolderUpAlt"
    static FolderUpBackspace := "FolderUpBackspace"
    static Taskbar := "Taskbar"
    static AltEnter := "AltEnter"
    static WindowFixed := "WindowFixed"

    static AnkiExecutable := "anki.exe"
    static AnkiPythonExecutable := "pythonw.exe"
    static AnkiPythonPath := "i)\\AnkiProgramFiles\\"
    static AnkiEditorTitle := "i)^(Add|Edit Current|Browse|添加|编辑当前|浏览)"
    static VolumePopupExecutable := "SndVol.exe"

    ; 名单来自 AHK-SysUtil 的 Global.ahk 和 IO/Switch.ahk。
    static Definitions := Map(
        WindowGroups.AltEnter, [
            "ahk_exe EXCEL.exe", "ahk_exe et.exe", "ahk_exe scalc.exe", "ahk_exe ONENOTE.exe",
            "ahk_exe cmd.exe", "ahk_exe powershell.exe", "ahk_exe pwsh.exe", "ahk_exe WindowsTerminal.exe",
            "ahk_exe MobaXTerm.exe", "ahk_exe mintty.exe", "ahk_exe bash.exe",
            "ahk_exe Code.exe", "ahk_exe devenv.exe", "ahk_exe qtcreator.exe", "ahk_exe sublime_text.exe",
            "ahk_exe pycharm64.exe", "ahk_exe idea64.exe", "ahk_exe clion64.exe", "ahk_exe uv4.exe",
            "ahk_exe notepad3.exe", "ahk_exe notepad++.exe", "ahk_exe EmEditor.exe"],
        ; 沿用 WindowOperation.ahk 的系统组件禁用名单，普通资源管理器窗口不受限。
        WindowGroups.WindowFixed, [
            "ahk_exe ShellExperienceHost.exe", "ahk_exe SearchHost.exe", "ahk_exe SearchApp.exe",
            "ahk_exe explorer.exe ahk_class WorkerW", "ahk_exe explorer.exe ahk_class Progman",
            "ahk_exe explorer.exe ahk_class DV2ControlHost", "ahk_exe explorer.exe ahk_class XamlExplorerHostIslandWindow",
            "ahk_exe explorer.exe ahk_class TopLevelWindowForOverflowXamlIsland", "ahk_exe explorer.exe ahk_class NotifyIconOverflowWindow",
            "ahk_exe explorer.exe ahk_class Windows.UI.Core.CoreWindow", "ahk_exe explorer.exe ahk_class WHCFlyoutWindow",
            "ahk_exe explorer.exe ahk_class NativeHWNDHost", "ahk_exe explorer.exe ahk_class ClockFlyoutWindow",
            "ahk_exe explorer.exe ahk_class BatMeterFlyout"],
        WindowGroups.RemoteDesktop, [
            "ahk_exe mstsc.exe ahk_class TscShellContainerClass", "ahk_exe ToDesk.exe", "ahk_exe RustDesk.exe",
            "ahk_exe SunloginClient.exe", "ahk_exe TeamViewer.exe", "ahk_exe AnyDesk.exe",
            "ahk_exe parsecd.exe", "ahk_exe GameViewer.exe", "ahk_exe dwagent.exe"
        ],
        WindowGroups.VirtualMachine, [
            "ahk_exe vmware.exe", "ahk_exe virtualbox.exe", "ahk_exe NanaBox.exe",
            "ahk_exe vmconnect.exe"
        ],
        WindowGroups.Anki, ["ahk_exe " WindowGroups.AnkiExecutable],
        ; 图片翻页用 Left/Right；这些窗口也支持中键转左键拖动。
        WindowGroups.ImageViewer, [
            "ahk_exe ImageGlass.exe", "ahk_exe Photos.exe", "ahk_exe photolaunch.exe",
            "ahk_exe BaiduNetdiskImageViewer.exe",
            "ahk_exe DllHost.exe ahk_class Photo_Lightweight_Viewer"
        ],
        ; 聊天工具只匹配图片子窗口。
        WindowGroups.ChatImageViewer, [
            "图片查看 ahk_exe TIM.exe", "图片查看器 ahk_exe QQ.exe",
            "ahk_exe WeChat.exe ahk_class ImagePreviewWnd",
            "Photos and Videos ahk_exe Weixin.exe", "图片和视频 ahk_exe Weixin.exe",
            "ahk_exe DingTalk.exe ahk_class DingImgViewWnd", "Media viewer ahk_exe Telegram.exe"
        ],
        WindowGroups.MiddleDragLeft, ["ahk_class SunAwtFrame ahk_exe javaw.exe"],
        WindowGroups.MiddleDragSpaceLeft, [
            "ahk_exe Photoshop.exe", "ahk_exe InDesign.exe", "ahk_exe Illustrator.exe",
            "ahk_exe AcroRD32.exe", "ahk_exe Acrobat.exe", "ahk_exe Muse.exe"
        ],
        ; 前进/后退的特殊处理类别；这里只分类，具体动作由 apps/actions 实现。
        WindowGroups.NavigationNative, ["ahk_exe understand.exe", "ahk_exe Notion.exe"],
        WindowGroups.NavigationAltShift, ["ahk_exe okular.exe"],
        WindowGroups.NavigationBackspace, [
            "ahk_exe 7zFM.exe", "ahk_exe NanaZip.exe", "ahk_exe NanaZip.Modern.exe",
            "ahk_exe 360zip.exe", "ahk_exe UltraISO.exe", "ahk_exe OneCommander.exe"
        ],
        WindowGroups.Explorer, ["ahk_exe explorer.exe"],
        WindowGroups.FileManager, ["ahk_exe XYplorer.exe", "ahk_exe totalcmd.exe", "ahk_exe totalcmd64.exe", "ahk_exe files.exe"],
        WindowGroups.FolderUpAlt, ["ahk_exe WinRAR.exe"],
        WindowGroups.FolderUpBackspace, ["ahk_exe Bandizip.exe", "ahk_exe HaoZip.exe"],
        WindowGroups.Taskbar, ["ahk_exe explorer.exe ahk_class Shell_TrayWnd", "ahk_exe explorer.exe ahk_class Shell_SecondaryTrayWnd"],
        WindowGroups.CajViewer, ["ahk_exe CAJVieweru.exe"],
        WindowGroups.PowerIso, ["ahk_exe PowerISO.exe"],
        WindowGroups.SiYuan, ["ahk_exe SiYuan.exe"],
        WindowGroups.Cad, [
            "ahk_exe acad.exe", "ahk_exe Inventor.exe", "ahk_exe AutoCAD.exe",
            "ahk_exe ZWCAD.exe", "ahk_exe DraftSight.exe", "ahk_exe BricsCAD.exe",
            "ahk_exe nanoCAD.exe", "ahk_exe SLDWORKS.exe", "ahk_exe CATIA.exe", "ahk_exe Siemens.exe"
        ])

    static Includes := Map(
        WindowGroups.AltEnter, [WindowGroups.FileManager],
        WindowGroups.WindowFixed, [WindowGroups.Taskbar],
        WindowGroups.XButtonPassthrough, [WindowGroups.RemoteDesktop, WindowGroups.VirtualMachine],
        WindowGroups.MiddleDragLeft, [WindowGroups.ImageViewer, WindowGroups.ChatImageViewer],
        WindowGroups.FileManager, [WindowGroups.Explorer],
        WindowGroups.FolderUpAlt, [WindowGroups.FileManager],
        WindowGroups.FolderUpBackspace, [WindowGroups.NavigationBackspace])

    static Register() {
        for name, rules in this.Definitions {
            for rule in rules
                GroupAdd(name, rule)
        }
    }

    ; 统一通过此接口查询，以包含组合分组和 Anki 的 Python 入口。
    static Matches(name, hwnd) {
        if !hwnd
            return false
        if this.Definitions.Has(name) && WinExist("ahk_group " name " ahk_id " hwnd)
            return true
        if this.Includes.Has(name) {
            for child in this.Includes[name] {
                if this.Matches(child, hwnd)
                    return true
            }
        }
        try {
            if name == this.WindowFixed {
                target := "ahk_id " hwnd
                return WinGetProcessName(target) = this.VolumePopupExecutable && WinGetTitle(target) == ""
            }
            ; if name == this.FileManager
                ; return RegExMatch(WinGetProcessName("ahk_id " hwnd), this.QDirExecutable)
            if name == this.Anki {
                winTitle := "ahk_id " hwnd
                process := WinGetProcessName(winTitle)
                return process = this.AnkiPythonExecutable
                    && this.IsAnkiProcess(process, WinGetProcessPath(winTitle))
            }
            if name == this.AnkiEditor
                return this.Matches(this.Anki, hwnd) && RegExMatch(WinGetTitle("ahk_id " hwnd), this.AnkiEditorTitle)
        } catch TargetError {
            return false
        }
        return false
    }

    static IsAnkiProcess(process, path) {
        return process = this.AnkiExecutable
            || (process = this.AnkiPythonExecutable && RegExMatch(path, this.AnkiPythonPath))
    }
}
