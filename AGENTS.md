# 项目指南

阅读本文件时必须同时阅读 [README.md](README.md)。同一信息只在一份文档中维护，其他文档按需引用。用户可见的功能、用途和热键表统一写入 README，每项通常不超过两句话。开发约束、实现细节和验证要求写在本文件。需求变化时直接修订对应条目并消除矛盾。

## 范围与参考

- 使用 AutoHotkey v2 重写 AHK-SysUtil。保持私人使用范围，舍弃旧版 RAlt Mode、热字串和冗余符号绑定。设置集中在托盘，独立设置或关于界面限于必要的核心操作。
- 移植时优先参考同级目录 `../AHK-SysUtil/` 的 AHK v1 实现。废弃原型 `../AHK-SysUtil2/src/` 中可参考 `Utils/{Utils,Json,Config}.ahk`、`System/{IME,System,Window}.ahk`、`String/StrUtils.ahk` 和 `Input/{Keyboard,Touchpad}.ahk`。跨平台热键可对照 `../custom-karabiner-config/`。
- 使用 README 中的 Layer 术语。涉及物理映射、扫描码或转发目标时写具体键名。

## 代码组织

- `main.ahk` 显式引用模块。`src/core/` 组装对象，管理项目配置、运行会话和开机启动。
- AHK 函数封装在类中，类名用 PascalCase，目录和文件名用小写下划线。用有意义的常量表示固定值，按职责重构，避免层层追加回退逻辑。优先降低空闲 CPU 占用和热键触发延迟。
- `src/lib/` 提供 JSON、配置、进程、系统输入与窗口操作等基础能力，`src/utils/` 放通用辅助类。打字、剪贴板、文本变换、自动编辑、窗口操作各自独立。应用策略归 `src/rules/editing.ahk`，第二剪贴板状态归 `src/actions/clipboard.ahk`。
- `src/hotkeys/` 实现原生钩子、层状态、注册和分发，由外部注入别名与策略。`src/rules/` 声明绑定、窗口分类和菜单布局，`src/actions/` 持有动作及其状态，`src/apps/` 封装应用专用操作。`src/ui/` 只接收命令和状态查询，基础库不依赖界面或应用名单。
- AHK 负责输入分发和剪贴板，`src/lib/python.ahk` 定位解释器并启动任务。复杂文本处理归 `py/text_actions.py`，复杂界面使用 `py/gui/` 中的 tkinter，公共辅助代码放 `py/utils/`。图标放 `res/`，测试放 `tests/`，调试产物放不提交的 `tmp/`。

## 配置与启动

- `Startup.RequireAdmin()` 在 `App.Start()` 前检查 `A_IsAdmin`，通过 `*RunAs` 提权，`/restart` 防止循环；取消或失败即退出。随后加载配置、定位 Conda Python、注册热键并创建托盘。开机启动使用当前用户启动目录的快捷方式。
- `src/core/settings.ahk` 中的模型继承 `Config.IConfig`。App 用 `AppSettings.GetDirectory()` 定位 `~/.config/custom-autohotkey-config/settings.json`，分组为 `Keyboard`、`Mouse`、`Window`、`Python`、`PersonalScripts`、`RemoteDesktop`、`IME`。`Python.condaEnvironment` 默认 `base`。
- 显式创建 `Config.Manager(filename, directory)`，依次调用 `Register(instance, name)`、`LoadAll()`。设置修改及退出时调用 `SaveAll()`；`ResetAll()` 只恢复注册时的默认值。独立 JSON 使用 `Config.LoadJson(path)` 和 `Config.SaveJson(value, path)`。
- 配置支持嵌套类、Map 和 Array。保存时保留未知字段，内容相同则跳过写盘，加载失败保留原文件及当前配置。JsonGo 将布尔值表示为 `1/0`、`null` 表示为空字符串，写出无 BOM 的 UTF-8。
- 重读成功后应用配置并刷新菜单勾选。暂停和功能键鼠标模式属于会话状态，均不写盘，重读时保留。`Mouse.xButtonMapping` 默认启用，与暂停状态独立。
- `rules/setting_inputs.ahk` 声明编辑规则。`Mouse.pointerFastStep`、`Mouse.wheelMultiplier` 为正整数，`Window.passThroughOpacityPercent` 为 0–100 的整数，后者在下次开启穿透时生效。输入框预填当前值，校验失败提示并保留输入，取消不写盘。字符串窗口可双向缩放；`InputRule.Text` 默认单行、开启折行，视觉折行不改变保存值。

## 热键与输入生命周期

- 键盘和鼠标绑定分别声明在 `src/rules/hotkeys.ahk`、`src/rules/mouse.ahk`，诊断实现归 `actions/diagnosis.ahk`。`registry.Layers(key, Map(1, action), …)` 每个 Map 只指定一层。未声明层不拦截、不执行、不降级。
- `registry.Pass(key, callback)` 保留修饰键。`registry.App(winTitle)` 优先于全局绑定，同一应用按键的空白层不回退。回调接收 `HotkeyContext`，从中读取释放前的窗口、修饰键、层号和触发键。
- 本地钩子按真实键码检查开关，拦截启用别名的按下、重复和抬起，放行关闭的别名。识别物理及逻辑修饰键。分层动作前仅释放系统侧修饰键，结束或异常时仅恢复仍按住的原有修饰键；恢复 Alt/Win 后屏蔽单键菜单激活，显式释放按键的动作除外。
- `Layers` 可重复，GUI 和菜单用 `Once` 消费会话，允许同一按键按层混用。消费后继续吸收已触发键和当前匹配的热键，直到所有别名松开。滚轮不注册 KeyUp。
- 仅在最后一个别名抬起且会话未使用时执行输入法切换；穿透和滚轮也标记为已使用。暂停、远程转发和已消费的会话不执行松开动作。`WM_EXITMENULOOP` 后由输入层补齐遗漏的 KeyUp，保留仍按住的键，不触发输入法切换。
- `HotkeySession` 统一控制启停。暂停时拒绝新动作，仍处理已捕获按键的抬起并释放模拟中键。「重置钩子」先收尾，再用 `NativeHotkeys.ResetHooks()` 重装键盘和鼠标钩子，保留开关及暂停状态，不重复注册热键。
- `AnkiStyles(sender, tooltip)` 提供 `Send(style)` 和 `Clear()`，Meta 对应 Win，未绑定的 `bg_gm` 不发送输入。旧表中的单引号行末冒号尚未注册。高级目录处理、符号链接及哈希界面使用外部同类工具。
- 输入法 API、方法表、语言分流分别归 `lib/ime.ahk`、`rules/ime.ahk`、`actions/ime.ahk`。保留常用方法，`chineseToggle` 为 `ctrl_space`（默认）、`api`、`shift`、`weasel`（小狼毫魔改 Ctrl+F20）；`chinesePunctuation` 为 `ctrl_period`（默认）或 `weasel`（小狼毫魔改 Ctrl+F21）；`koreanToggle`、`japaneseToggle` 除 `api` 外分别默认 `hangul`、`alt_grave`。韩文汉字键用 VK_HANJA，`JapaneseIme.Hiragana()` / `.Katakana()` 默认发 Ctrl+CapsLock / Alt+CapsLock，传入 `JapaneseIme.KanaKey` 改用 Kana / Shift+Kana。
- 打字粘贴期间关闭 IME，ASCII 使用扫描码，非 ASCII 使用文本。中文恢复用队尾 Ctrl+Space 并等待状态确认，韩文、日文暂用 300 ms 后 API 恢复；异常时也须恢复。高级粘贴沿用 CMake GUI 的路径转换规则，无需输入框。

## 窗口与鼠标

- 前台分类集中于 `src/rules/windows.ahk`，`Definitions` 声明原生匹配项，`Includes` 组合类别，统一通过 `WindowGroups.Matches(group, hwnd)` 查询。`WindowGroups.WindowFixed` 管理桌面、任务栏和旧版系统弹窗等组件，限制置顶、透明度调整及开启穿透，始终允许关闭已有穿透。
- `caps_policy.ahk` 按窗口组和 `RemoteDesktop.capsMode` 路由所有启用的别名。对 `mstsc.exe` 仅匹配 `TscShellContainerClass`。切换模式不重装钩子；转发按下与抬起固定同一目标，共用目标的别名全部松开才发送抬起，暂停和退出时释放转发键。
- `actions/xbuttons.ahk` 管理侧键生命周期，`apps/xbuttons.ahk` 按窗口组同时选择动作和提示。将 `Keys`、`Tips` 直接写在规则中，原始穿透及未执行动作不提示。CAJ/PowerISO 各自持有布局，`lib/window_geometry.ahk` 和 `lib/window_automation.ahk` 负责缩放、控件点击和点击序列，自动点击后恢复指针位置。
- `MiddleDragPolicy` 选择按键，`MiddleDragController` 管理按下到抬起，窗口切换不改变释放对象。指针移动按物理像素计算，不显示 Tooltip。
- `rules/wheel.ahk` 优先处理 Layer，其次处理 Win，最后处理任务栏上的无修饰键滚轮。`lib/touchpad.ahk` 注入双触点，接触面积随触点更新并保持有效。`TouchpadActions` 管理轨迹及暂停、失败收尾。不得通过拦截右键或发送 Esc 掩盖误触。
- `WindowActions` 实例持有穿透状态，失效句柄及时清理。批量操作先验证目标，动作入口捕获窗口、系统 API 和剪贴板错误，通过注入的 `TooltipPresenter` 或对话框反馈原因。
- 基础库向上抛错，`core/runtime_errors.ahk` 以 Tooltip 报告未处理异常并结束当前动作。`finally` 恢复剪贴板、输入法及修饰键；触点和模拟按键在成功释放后才清空状态，某控制器清理失败时继续清理其余控制器。

## 托盘、界面与外部工具

- `rules/tray.ahk` 维护菜单布局。保留 AHK 原生菜单和双击 Open。功能键鼠标映射放顶层，「打开配置目录」和「重新读取配置」相邻，前面加分隔线；这两项及「其他设置」用系统图标。启动、运行、自定义暂停分别用 `MainBusy.ico`、`MainIcon.ico`、`MainSuspend.ico`，不冻结图标，原生 Suspend/Pause 沿用 AHK 状态图标。
- 「其他工具」紧随「快捷路径与系统工具」。在灰色标题「以下为 PersonalScripts 工具」下按键盘与文字、系统、文件与同步、其他工具平铺分组，组间加分隔线。窗口信息紧跟系统事件查看器，屏幕遮挡器设两个创建子项，run-script 启动器在末尾单列。复杂 GUI 默认另设热键，键盘映射编辑器、系统事件查看器、图片文字与公式识别、矩阵查看器只设托盘入口。
- 目录项在 `rules/paths.ahk` 声明，`ui/popup_menu.ahk` 渲染原生菜单，`actions/paths.ahk` 执行并提示，`lib/shell.ahk` 查询系统目录、提取图标并启动目标。仅采用系统中与条目对应的图标。
- 热键和托盘共用启动命令。启动外部 GUI、命令行和系统工具前显示约两秒的「正在启动 工具名，请稍等…」提示并立即启动。新建或唤回的 Python 窗口须取得前台焦点；需保留输入目标的工具只前置显示。
- `actions/personal_scripts.ahk` 负责定位和启动外部脚本。`PersonalScripts.launcherPath` 为空或失效时，从 PATH 依次查找并保存 `run-script.ps1`、`run-script.py` 的路径。只用其目录定位目标脚本，缺少入口或脚本时弹窗提供 GitHub 安装链接。外部工具独立于 AHK 重载。
- `actions/window_inspector.ahk` 向 `tools/others/window-inspector.py` 传入触发时的 HWND、PID，托盘入口传 `--startup-window 0 0`。`actions/clipboard_tools.ahk` 将复制的选区保留在剪贴板中并传 `--clip`。托盘不复制选区，仅 Unicode 查看器读取已有剪贴板。
- `tools/input-and-text/screen-keyboard.py` 用 `--force-layer` 临时指定按 F24、CapsLock、F1 顺序选出的首个启用键，全关时省略参数。单实例、Prefs 及窗口生命周期归外部工具管理。
- `rclone-sync` 和 `run-script` 启动器使用项目配置的 Python 无参数启动，优先新建 Windows Terminal 窗口，失败时使用独立控制台，两者均启用 ANSI。
- 所有项目 GUI 使用 96 DPI 逻辑尺寸和 Per-Monitor V2，按 `WM_DPICHANGED` 同步窗口、字体、控件及最小尺寸，限制在当前显示器工作区内。Tk 共用 `py/utils/dpi_window.py`，AHK 共用 `ui/dpi_gui.ahk`，跨屏不轮询、不累积缩放。ctypes 原生回调只入队，由阻塞等待的工作线程转交 Tk 主线程。

## 验证

移植后验证真实输入及系统 API。出现错误或延迟时先复现，再分段计时定位。

- 配置用 `tests/test_json_config.ahk` 验证读写，用 `tests/test_json_interop.py <AHK v2 可执行文件路径>` 验证与 Python 互读。
- 热键注册、原生输入、菜单 KeyUp 和修饰键恢复分别见 `tests/test_hotkeys.ahk`、`test_input_native.ahk`、`test_caps_menu.ahk`、`test_modifier_restore.ahk`。编辑和输入法用 `test_editing.ahk`、`test_ime.ahk`、`test_typing_ime.ahk` 验证真实编辑控件、剪贴板及输入法状态恢复。
- 窗口失效和操作中关闭用 `test_window_errors.ahk` 验证，运行期清理用 `test_runtime_errors.ahk` 验证。远程路由、侧键、中键与滚轮分别见 `test_remote.ahk`、`test_xbuttons.ahk`、`test_middle_drag.ahk`、`test_wheel_touchpad.ahk`；`test_touchpad_edge.ahk` 用独立 Edge 页面验证缩放及零右键菜单事件。
- `tests/test_app.ahk` 检查菜单、图标、设置、鼠标收尾与启动快捷方式。其 `--keyboard-only` 模式验证屏幕键盘两个入口、重复唤回、四层分发和修饰键释放。`test_paths.ahk` 与 `test_personal_scripts.ahk` 分别覆盖目录菜单和外部工具入口。
