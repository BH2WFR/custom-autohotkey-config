# 项目指南

当前要制作一款私人键盘 Layer 小工具。

特殊层触发键统称为 `Layer`（caps layer key），热键写法仍保留 `Caps+按键`，其中 Caps 代表任一 Layer 触发键；物理映射和真实键码使用 CapsLock、F1、F24 等具体键名。

源项目 AHK-SysUtil 的源码目录： `D:\Projects\AHK_Scripts\AHK-SysUtil`，这是个 AHKv1 写的工具。

AHK-SysUtil 通过 Windows 注册表将 CapsLock 映射为 F24、RAlt 映射为 F23，以触发特殊层。以 Layer 为例，Caps+A 为第一层，Caps+Shift+A 为第二层；穿透热键保留系统修饰键，例如 Ctrl+Caps+Q 发送 Ctrl+Esc。

当前新工具需要用 AHKv2 完全重写，并进行以下的重大改进：

- 仅保留 Layer 特殊层；取消 RAlt 热键。彻底删除 RAlt Mode 的概念。
- 加入以 Caps+Alt 作为第 3/4 层热键的触发；Layer、Alt、Shift 不限按下顺序。
- 大量精简功能，取消特殊符号/过多的文本编辑/热字串功能
- 部分复杂功能改用 Python 实现，所有复杂 GUI 界面改用 Python tkiner 实现。
- 软件的设置功能不再使用注册表，而使用 json 格式。
- 针对私人使用用途做最大程度上的精简，取消所有设置和关于窗口。

本人为了测试，写过 AHK-SysUtil2 的新项目，该项目目前已废弃，但是含有一些比较重要的代码，可以参考：

```text
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\Utils\Utils.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\Utils\Json.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\Utils\Config.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\System\IME.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\System\System.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\System\Window.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\String\StrUtils.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\Input\Keyboard.ahk
D:\Projects\AHK_Scripts\AHK-SysUtil2\src\Input\Touchpad.ahk
```

当前已完成 macos 中 karabiner-elements 配置方案，其热键和功能与本工具高度相似，参考：`D:\Projects\AHK_Scripts\custom-karabiner-config`

本 AGENTS.md 可根据最新要求实时自动更新，并解决可能存在自相矛盾的地方。但语言必须简洁、不得含有与主要任务无关的免责/防御性信息，能用一句话说明白的，绝不使用两句话。

## 文件结构

- `main.ahk`：显式引用入口；`src/core/`：对象组装、项目配置模型、运行会话和开机启动。
- `src/lib/`：JSON、配置读写、Python 进程启动和系统输入等基础能力；`src/utils/`：通用辅助类，均不包含应用名单、项目绑定或具体 GUI 功能。
- 基础打字、剪贴板、文本转换、自动编辑和窗口操作分别位于 `lib/typing.ahk`、`clipboard.ahk`、`text.ahk`、`editing.ahk`、`window.ahk`；应用分流由 `rules/editing.ahk` 决定，第二剪贴板状态归 `actions/clipboard.ahk`。
- `src/hotkeys/`：原生钩子、层状态、注册容器、分发和按键路由机制；别名和策略由外部注入。
- `src/rules/`：可扩展的热键声明、窗口分类、Layer 策略和托盘布局；`src/actions/`：具体功能与其运行状态；`src/apps/`：应用专用功能。
- `src/ui/`：托盘等界面视图，只接收命令和状态查询，不直接访问 App、配置或功能内部对象。
- Caps+W 使用原生 AHK GUI：`lib/window_info.ahk`、`process.ahk` 查询系统，`actions/window_inspector.ahk` 管理目标及单实例，`ui/window_inspector.ahk` 渲染；选窗或刷新时立即读取进程详情，控件仍按按钮读取，未读取时列表显示提示，无轮询定时器。
- `ui/window_picker.ahk` 通过鼠标捕获实现拖拽选窗和粗框高亮，按物理坐标及目标显示器缩放绘制，释放、取消或关闭时清理捕获与边框，保留独立弹窗作为目标。
- `src/actions/xbuttons.ahk` 管理侧键生命周期，`src/apps/xbuttons.ahk` 按窗口类别分流，CAJ/PowerISO 模块持有各自布局；`src/lib/window_geometry.ahk` 和 `window_automation.ahk` 仅负责缩放换算、控件点击与点击序列。
- `py/main.py`：Python 功能入口；`py/text_actions.py`：复杂文本处理；`py/gui/`：tkinter 界面；`py/utils/`：公共辅助模块。
- AHK 统一管理热键、剪贴板和最终输入，Python 负责复杂处理和 GUI；`src/lib/python.ahk` 仅定位解释器并启动任务，屏幕键盘的单实例窗口及进程归 `src/actions/screen_keyboard.ahk` 管理。
- `src/actions/personal_scripts.ahk` 仅定位私人脚本库并启动相对路径脚本，不包含具体工具、剪贴板或界面逻辑；Unicode 查看器适配位于 `actions/unicode_inspector.ahk`，外部工具不随 AHK 重载退出。
- `res/`：图标等静态资源；`tests/`：测试；`tmp/`：不提交的调试产物；用户配置仍存放在 `~/.config/custom-autohotkey-config/`。
- 目录和文件使用小写下划线命名，AHK 类使用 PascalCase；占位文件随功能实现补充。

## 配置接口

- 项目配置模型位于 `src/core/settings.ahk`，继承 `Config.IConfig`；显式创建 `Config.Manager(filename, directory)`，依次 `Register(instance, name)`、`LoadAll()`，修改后 `SaveAll()`；App 使用 `settings.json` 和 `AppSettings.GetDirectory()`。
- `Config.Manager(filename, directory)` 可管理独立 JSON 文件；`ResetAll()` 恢复注册时的默认值，显式调用 `SaveAll()` 才写盘。
- 配置支持嵌套类、Map、Array；正常保存保留未知字段，无变更不写盘，加载失败不覆盖原文件；临时运行状态不放进配置类。
- `Config.LoadJson(path)`、`Config.SaveJson(value, path)` 用于独立文件；JsonGo 沿用布尔值 `1/0`、`null` 为空字符串的表示，写出 JSON 使用无 BOM 的 UTF-8。
- `tests/test_json_config.ahk` 验证 JSON 和配置行为；`tests/test_json_interop.py <AHK v2 可执行文件路径>` 验证 Python 互读。

## 细节指南

- 软件启动后，仍然保留托盘菜单和图标。托盘菜单中保留屏幕键盘、F1 作为 Layer 触发键（可保存状态）、F2/F3/F4 映射中键/滚动（不保存，启动时默认关闭）、是否交换横向滚动方向、是否开启 Win+鼠标滚轮调节窗口透明度等设置。
- 软件启动时，自动根据配置获取 conda 环境名称，并查找 python 入口，方便快速启动调用python的功能
- Layer 触发键固定为 CapsLock、F1（托盘可关闭）、F24（固定开启）、F6（由 `DebugMode` 控制，仅调试），F23 不注册为层键或输入法切换键。
- README.md 中随时写入各热键的功能介绍，通常每个功能的介绍不超过两句话，仅围绕其核心功能展开，不得出现与核心功能无关的交互、注意事项、或防御性语言等内容；由于功能还不稳定，暂时不写任何与功能说明无关的，如安装指南等内容。
- 所有 AHK 函数，均应当包裹到 class 中。本项目应当使用 OOP 风格的代码组织方式。
- 输入法相关功能，需要进行一定简化，取消过多的自定义功能，仅保留常规的几种配置。
- 配置文件写入到 `~/.config/custom-autohotkey-config/*.json` 中。
- 过度的防御性编程、防御性说明是不受欢迎的。
- 本项目运行时要将对系统 CPU 的占用降到最低。
- 可保留简化的关于/设置界面，设置中仅包含开机启动注册、按键映射、进程优先级、打开设置目录等核心功能。
- 热键默认保留 Layer 会话，松开功能键后可重复或交替触发；分层动作执行前释放系统侧修饰键和触发键，结束或异常时恢复仍按住的原有修饰键，恢复 Alt/Win 后屏蔽单键菜单激活，显式释放按键的动作不恢复。
- 前台为远程桌面或虚拟机窗口时，所有 Layer 触发键按 `RemoteDesktop.capsMode` 转发或使用本地层。
- 保持单一职责原则，不可以为了追求方便而增加代码耦合度。涉及窗口分类、热键注册等有可扩展性的内容，不可以与基础库放到一起。
- 禁止硬编码的魔鬼数字、魔鬼字符串。应当使用全局变量或类的static变量。
- 允许破坏性更新，该重构就重构，严禁当不断添加回退或防御性代码的糊裱匠。
- 热键处理系统，应确保从按下到开始执行过程中延迟越小越好。
- 涉及窗口操作、系统 API 调用、剪贴板读写等函数，要有异常捕获等兜底机制，在遇到句柄错误、窗口不存在等问题时能够正确地通过对话框或 tooltip 等方式反馈问题。

## 热键注册

- `src/rules/hotkeys.ahk` 中的 `HotkeyBindings` 仅声明热键，诊断动作位于 `src/actions/diagnosis.ahk`；鼠标绑定同样位于 `src/rules/mouse.ahk`，与功能控制器分离。
- 按键集中注册四层：`registry.Layers("a", Map(1, toggleCaps), Map(2, toggleNum))`；每个 Map 只声明一层，未声明的层不拦截、不触发、不降级。
- `registry.Pass(key, callback)` 注册不分层的修饰键穿透功能；`registry.App(winTitle)` 注册应用规则，优先于全局绑定。
- 回调接收 `HotkeyContext`，含释放前的窗口、修饰键、层号和触发键快照；状态和按键释放由调度器管理。
- 当前绑定基础编辑、剪贴板、窗口、鼠标、诊断、输入法及第 3/4 层功能；Caps+E 使用 AHK 原生目录菜单，Caps+Shift+Z、文件管理器中的符号链接和哈希界面暂缓。
- 目录菜单声明位于 `rules/paths.ahk`，`ui/popup_menu.ahk` 渲染原生菜单，`actions/paths.ahk` 执行命令并提示，`lib/shell.ahk` 负责系统目录查询、图标提取和启动；图标仅使用系统中存在且与条目对应的资源，`tests/test_paths.ahk` 验证菜单及提示。
- 输入层在 `WM_EXITMENULOOP` 后统一补齐遗漏的 KeyUp，保留仍按住的键且不触发输入法切换；菜单视图不参与层状态管理，`tests/test_caps_menu.ahk` 验证连续按键及菜单收尾。
- 旧版动作 Tooltip 由动作对象接收注入的 `TooltipPresenter` 显示，基础库不依赖界面；`WindowActions` 实例持有窗口穿透状态。
- 窗口操作在动作入口捕获异常并用 Tooltip 显示原因；先验证目标再执行最小化等批量操作，失效穿透句柄及时清理，基础库不吞掉错误；`tests/test_window_errors.ahk` 验证失效句柄及操作中关闭窗口。
- `core/runtime_errors.ahk` 统一以 Tooltip 报告运行期未处理异常并终止当前动作；基础库抛出错误，`finally` 恢复剪贴板、输入法及修饰键，触点和模拟按键释放成功后才清空状态，暂停和退出继续清理其他控制器。
- 桌面、任务栏及旧版系统弹窗名单统一归 `WindowGroups.WindowFixed`，禁止置顶、透明度调整和开启穿透，已有穿透始终允许关闭；应用限制不放入基础窗口库。
- `Q`、`U/I/O/J/K/L` 和反斜杠穿透所有修饰键；`I/J/K/L` 每次移动 1 个物理像素，Shift 默认 10 个，由 `Mouse.pointerFastStep` 设置，移动不显示 Tooltip；Anki 专用规则优先。
- `tests/test_hotkeys.ahk` 验证注册与分流，`tests/test_editing.ahk` 验证文本转换、真实编辑控件、剪贴板恢复、ASCII 扫描码、Unicode 和窗口状态。
- `Layers` 默认可重复，`Pass` 同时穿透修饰键；GUI、菜单用 `Once` 结束本次层，同一按键的不同层可分别使用 `Once` 和 `Layers`，应用规则同样支持，滚轮不注册 KeyUp。
- 一次性动作结束层后，在所有 Layer 触发键松开前继续吸收已触发键及当前匹配的热键，不能泄漏为普通输入；如 Layer 不松开连按两次 E，第二次不得打开菜单或输入 e。
- `src/apps/anki.ahk` 提供 `AnkiStyles(sender, tooltip).Send(style)` 和 `Clear()`，按本文 Anki 表注册，Meta 对应 Win；`bg_gm` 无快捷键且不发送输入。非 Anki 窗口回退默认功能，无默认功能则无动作；匹配 Anki 专用按键后，空白层不回退。

## 启动与托盘

- `main.ahk` 先调用 `Startup.RequireAdmin()`，用 `A_IsAdmin` 检查权限并通过 `*RunAs` 提权重启；取消或提权失败则退出，`/restart` 防止循环重启，随后才执行 `App.Start()`。
- `App.Start()` 加载配置、定位 Conda Python、注册热键并创建托盘；图标使用 `res/MainBusy.ico`、`MainIcon.ico`、`MainSuspend.ico`。
- 托盘图标不冻结：自定义暂停使用 `MainSuspend.ico`，原生 Suspend/Pause 使用 AHK 自带状态图标，恢复后显示项目图标。
- 托盘顶层保留 F1、F2/F3/F4 映射、打开配置目录及其下方的重新读取配置，侧键映射、反转横向滚动等收进“其他设置”；配置目录上方加分隔线，配置目录、重新读取及其他设置使用系统图标；保留 AHK 原生菜单和双击 Open。
- JSON 在启动时读取、设置修改和退出时保存；托盘“重新读取配置”即时应用并刷新勾选，保留暂停及 F2/F3/F4 临时状态，读取失败保留原有运行配置。
- JSON 分组为 `Keyboard`、`Mouse`、`Python`、`PersonalScripts`、`RemoteDesktop`、`IME`；`Python.condaEnvironment` 默认 `base`，F2/F3/F4 模式和暂停状态不持久化。
- `PersonalScripts.launcherPath` 为空或失效时依次从 PATH 查找 `run-script.ps1`、`run-script.py` 并保存，找不到则弹出错误对话框；仅用其目录定位目标脚本，不执行启动器。
- `Mouse.xButtonMapping` 默认开启，由托盘“侧键映射”切换并保存；全局暂停独立于此设置。
- `Mouse.pointerFastStep` 默认 `10`，`Mouse.wheelMultiplier` 默认 `5`，均为仅在 JSON 中编辑的正整数，重新读取后立即生效；Caps+Shift+滚轮每次横向滚动一格。
- `IME.chineseToggle` 支持 `api`、`ctrl_space`（默认）、`shift`、`weasel`，`chinesePunctuation` 支持 `ctrl_period`（默认）、`weasel`，均可在托盘“输入法”菜单切换保存。
- IME 基础接口位于 `src/lib/ime.ahk`，方法表在 `src/rules/ime.ahk`，语言分流在 `src/actions/ime.ahk`；`koreanToggle` 支持 `api`、`hangul`（默认），`japaneseToggle` 支持 `api`、`alt_grave`（默认），韩文汉字使用 VK_HANJA。
- 同文件中的 `JapaneseIme(sender).Hiragana()` / `.Katakana()` 默认发送 Ctrl+CapsLock / Alt+CapsLock，传入 `JapaneseIme.KanaKey` 改用 Kana / Shift+Kana；日文下分别绑定 Caps+. / Caps+Shift+.。
- 托盘“重置钩子”由 `HotkeySession` 协调控制器收尾并调用 `NativeHotkeys.ResetHooks()` 强制重装键盘/鼠标钩子，保留开关与暂停状态，不重复注册热键。
- 屏幕键盘使用 tkinter 复刻 macOS RDP 六行布局，Layer 和修饰键支持单次保留、长按锁定；Windows 非激活窗口不抢焦点，输入经 `actions/screen_keyboard.ahk` 转交 `hotkeys/virtual_keyboard.ahk` 复用注册表及分发器，暂停和关闭清理会话，AHK 退出或重载时关闭所属 Python 窗口。
- 屏幕键盘不显示或持续监听前台窗口，切换应用不隐藏键盘；操作键盘时核对目标，目标变化则清理上一窗口的按键状态。
- 屏幕键盘默认 512×197，无最小化按钮；置顶界面显示后再次置前，屏幕键盘提升 Z 序但不抢输入焦点，普通 GUI 同时激活。
- 所有项目 GUI 按 96 DPI 逻辑尺寸设计，使用 Per-Monitor V2 和 `WM_DPICHANGED` 同步窗口、字体、控件及最小尺寸；Tk 共用 `py/utils/dpi_window.py`，AHK 共用 `ui/dpi_gui.ahk`，跨屏不轮询、不累积缩放，窗口限制在当前显示器工作区内。
- 屏幕键盘布局与界面统一放在 `py/gui/screen_keyboard.py`；悬停仅提亮底色，保留前景色，按键使用浅色单像素边框。
- “更多”和其右侧的“数字”是独立开关，分别控制下方单行特殊键和右侧小键盘，可同时展开；任一区域展开时每 250 ms 读取锁定键状态，有变化才刷新，NumLock 决定小键盘标签及发送的数字/导航键。
- 同一 AHK 宿主的 Python 屏幕键盘以 Windows 命名互斥量保证单实例；重复启动等待原窗口就绪，通知其移到鼠标附近后退出新进程。
- ctypes 原生窗口回调只将命令入队，由阻塞等待的工作线程交给 Tk 主线程，禁止在原生回调中直接调用 Tk。
- `tests/test_screen_keyboard.ahk` 启动独立编辑窗口及 Python 键盘，通过真实鼠标点击验证四层、修饰键、应用分流、重复触发、Once 吞键和焦点保持。
- 暂停时禁止新动作，保留已捕获按键的抬起处理并释放模拟中键；开机启动通过用户启动目录的快捷方式管理。
- `tests/test_app.ahk` 检查菜单、图标、配置、鼠标收尾、临时启动快捷方式与 Python 窗口生命周期。
- `tests/test_xbuttons.ahk` 检查应用分流、侧键收尾、点击布局及缩放换算；`HotkeySession` 统一切换各输入控制器的启用状态。
- 中键拖动由 `MiddleDragPolicy` 选择按键、`MiddleDragController` 管理按下到抬起；暂停或退出释放所模拟的按键，窗口切换不改变释放对象，`tests/test_middle_drag.ahk` 验证生命周期及分组。
- 滚轮优先级为 Layer 连续滚动、Win 透明度、无修饰键的任务栏音量，规则在 `src/rules/wheel.ahk`；`src/lib/touchpad.ahk` 注入双触点，`TouchpadActions` 负责缩放轨迹及暂停/失败收尾，`tests/test_wheel_touchpad.ahk` 验证路由、DPI 和触点生命周期。
- 触摸注入保留有效接触面积并随触点更新；`tests/test_touchpad_edge.ahk` 用独立 Edge 页面验证缩放及零右键菜单事件，不能通过拦截右键或发送 Esc 掩盖误触。

## 远程桌面

- `src/rules/windows.ahk` 集中维护前台窗口分类；`caps_policy.ahk` 将远程桌面类别和配置转换为路由，基础钩子不包含应用名单。
- 分类统一通过 `WindowGroups.Matches(WindowGroups.<类别>, hwnd)` 查询，包含 Anki/编辑窗口、图片/聊天看图窗口、中键拖动、远程/虚拟机侧键穿透和前进/后退特殊应用；`Definitions` 维护原生匹配项，`Includes` 组合已有类别。
- `RemoteDesktop.capsMode` 可设为 `CapsLock`、`F1`、`F24` 或 `layer`，默认 `F1`，托盘可切换并保存；所有启用的 Layer 触发键共用此设置，不自动重装钩子。
- `mstsc.exe` 仅将 `TscShellContainerClass` 识别为远程桌面，`#32770` 等其他窗口使用普通 Layer 行为。
- 转发模式保留修饰键且不执行本地 Layer，按下到抬起固定同一目标；多个别名共享目标时，最后一个松开才发送抬起；暂停与退出释放已转发的键。
- `tests/test_remote.ahk` 验证窗口分类、路由选择、模式切换及按键收尾。

## 热键列表

Layer 未执行热键时，最后一个别名松开触发输入法语言切换；穿透热键同样标记为已使用，消费、暂停取消、远程转发均不触发松开动作，`tests/test_ime.ahk` 验证该流程和语言分流。

按键盘从上到下、从左到右排列；图中双行功能的下行为 Layer，上行为 Caps+Shift 层。空白项用“—”表示，已划掉的功能不纳入。

| 按键 | Caps+按键 | Caps+Shift+按键 |
| --- | --- | --- |
| `` ` `` | 释放修饰键 | — |
| 1 | 前台窗口、修饰键和层信息 [修饰键穿透] | [修饰键穿透] |
| 2 | 第 1 层信息 | 第 2 层信息 |
| 4 | 将选中文本包在 `${` 和 `}` 中 | — |
| 6 | 选中文本转小写 | 选中文本转大写 |
| 7 | PersonalScripts Unicode 字符查看器 | 选中文本每个单词首字母大写，其余小写 |
| - | 模拟触控板缩小 | 向左横向滚动 |
| = | 模拟触控板放大 | 向右横向滚动 |
| BackSpace | 删除两字词第一字 | 删除当前行 |
| Tab | 缩进选中文本 | 反向缩进选中文本 |
| Q | 发送 Esc [修饰键穿透] | [修饰键穿透] |
| W | 窗口信息 | — |
| E | 快捷目录菜单 | — |
| R | 窗口居中 | 重置窗口大小 |
| T | 窗口置顶 | — |
| U | 鼠标左键 [修饰键穿透] | [修饰键穿透] |
| I | 鼠标指针向上移动 1px | 鼠标指针向上移动 10px（默认） |
| O | 鼠标右键 [修饰键穿透] | [修饰键穿透] |
| P | Pause | ScrollLock |
| \ | 发送 ISO `\` [修饰键穿透] | [修饰键穿透] |
| A | 切换 CapsLock 状态 | 切换 NumLock 状态 |
| S | 屏幕键盘 | — |
| D | 显示桌面 | 最小化其他窗口 |
| J | 鼠标指针向左移动 1px | 鼠标指针向左移动 10px（默认） |
| K | 鼠标指针向下移动 1px | 鼠标指针向下移动 10px（默认） |
| L | 鼠标指针向右移动 1px | 鼠标指针向右移动 10px（默认） |
| ; | 行末分号 | 行末冒号 |
| ' | 行末冒号 | — |
| Enter | 在当前行下方插入新行 | 在当前行上方插入新行 |
| Z | 自动打字粘贴 | 高级目录处理 |
| X | 剪切 | 剪切当前行 |
| C | 复制 | 复制当前行 |
| V | 纯文本粘贴 | 高级粘贴 |
| B | 窗口穿透 | 不透明度 20%→40%→60%→80%→100%，其他值重置为 100% |
| , | 行末加 `,` | 行末加 `\` |
| . | 中文：中英标点；韩文：汉字键；日文：平假名 | 日文：片假名；其他输入法菜单待实现 |
| Space | 不间断空格 | 全角空格 |

Caps+Alt 第 3/4 层热键：

| 按键 | Caps+Alt+按键 | Caps+Alt+Shift+按键 |
| --- | --- | --- |
| 1 | 前台窗口、修饰键和层信息 [修饰键穿透] | [修饰键穿透] |
| 2 | 第 3 层信息 | 第 4 层信息 |
| Tab | 强制输入制表符 | — |
| T | set 函数名输入 | get 函数名输入 |
| Enter | 强制输入换行符 `\n` | 强制输入回车换行符 `\r\n` |
| Z | [第二剪贴板] 自动打字粘贴 | — |
| X | [第二剪贴板] 剪切纯文本 | [第二剪贴板] 剪切当前行 |
| C | [第二剪贴板] 纯文本复制 | [第二剪贴板] 复制当前行 |
| V | [第二剪贴板] 纯文本粘贴 | [第二剪贴板] 高级粘贴 |

Anki 中，Layer 特殊热键：

| 按键 | Caps+按键 | Caps+Shift+按键 |
| --- | --- | --- |
| Q | 清除样式 | — |
| W | `sz_large` | — |
| E | `bg_yl` | `st_inv` |
| R | `bg_lm` | `bg_cy` |
| T | `bg_cy` | — |
| A | `cl_gy` | `cl_gn` |
| S | `cl_or` | `cl_bl` |
| D | `fg_or` | `fg_gy` |
| F | `fg_rd` | `fg_bl` |
| G | `fg_gn` | `fg_bl` |

- Caps+Q 接收系统修饰键，例如 Ctrl+Caps+Q 发送 Ctrl+Esc。
- Caps+Z 的 ASCII 字符发送扫描码，非 ASCII 使用文本发送；打字期间临时关闭 IME，中文恢复用队尾 Ctrl+Space 并等待状态确认，禁止用固定延时判定中文输入完成；韩文、日文暂保留 300 ms 后 API 恢复，异常时同样恢复，第 3 层使用第二剪贴板。
- Caps+Shift+Z 使用 Python tkinter GUI，功能同原 AHK-SysUtil 中 Caps+Shift+V 的高级粘贴功能。
- Caps+Shift+V 和第 4 层 V 高级粘贴不弹输入框，路径沿用 CMake GUI 的正斜杠转换；C/Shift+C 保持复制/复制当前行。
- RDP 中 Layer 默认映射为 F1，可在托盘切换为 CapsLock、F24 或本地层。

## 特殊功能：

- 鼠标侧键按 WindowGroups 规则同时选择动作和 Tooltip，Keys 和 Tips 直接写在规则中，不另抽常量或按热键反查；Anki 使用默认前进/后退，原始穿透或未执行动作时不提示。
- Caps+鼠标滚轮：快速滚动；Caps+Shift+鼠标滚轮：横向滚动
- 保留在各别图片查看器中，鼠标中键拖动功能；
- 任务栏（含副屏任务栏）中，可通过滚动鼠标滚轮以调节音量
- Win+鼠标滚轮，可给当前窗口调整透明度，此功能可关闭


## 编译与调试

待写

- 本电脑已加入 CapsLock->F24 的注册表按键映射，由 F24 直接触发 Layer；F6 保留为调试别名。
- 沿用 AHK-SysUtil 的成熟实现；移植后验证实际输入及系统 API 行为，出现错误或延迟时通过复现和分段计时定位，不以模拟测试代替实机验证。
