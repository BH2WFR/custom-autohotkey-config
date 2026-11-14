# Custom Autohotkey Config

macOS 姊妹项目：[custom-karabiner-config](https://github.com/BH2WFR/custom-karabiner-config)。

本工程中，Caps+7 Unicode字符查看器会调用此项目中的代码：[PersonalScripts](https://github.com/BH2WFR/PersonalScripts)

特殊层触发键统称为 **Layer**（caps layer key），对应 CapsLock、F1、F24 和仅调试启用的 F6；F1 可在托盘菜单中切换并保存，F24 固定开启。

热键沿用 `Caps+按键` 的写法，其中 Caps 代表任一 Layer 触发键。

| 热键 | 功能 |
| --- | --- |
| Layer 单独按下并松开 | 当前输入法中切换中/英、韩/英或日/英输入。 |
| Caps+反引号 | 释放修饰键及本次层触发键。 |
| Caps+1 | 用 Tooltip 显示前台窗口、修饰键和当前层，保留修饰键与 Layer 会话。 |
| Caps+2 | 显示第 1 层信息。 |
| Caps+Shift+2 | 显示第 2 层信息。 |
| Caps+Alt+2 | 显示第 3 层信息。 |
| Caps+Alt+Shift+2 | 显示第 4 层信息。 |
| Caps+4 | 将选中文本包在 `${` 和 `}` 中。 |
| Caps+6 / Caps+Shift+6 | 选中文本转小写 / 大写。 |
| Caps+7 | 用 PersonalScripts 的 Unicode 字符查看器分析选中文本，显示码点、编码及字符信息；无选区时打开空白查看器。 |
| Caps+Shift+7 | 选中文本每个单词的首字母大写，其余字母小写。 |
| Caps+- / Caps+= | 在鼠标位置模拟双指缩小 / 放大手势，距离随显示器缩放调整，并显示缩放方向提示。 |
| Caps+Shift+- / Caps+Shift+= | 向左 / 向右横向滚动。 |
| Caps+Backspace / Caps+Shift+Backspace | 删除二字词第一字 / 删除当前行。 |
| Caps+Tab / Caps+Shift+Tab | 当前行或多行选区缩进 / 取消缩进，使用四个空格并识别制表符。 |
| Caps+Q | 发送 Esc，穿透修饰键。 |
| Caps+W | 原生窗口信息查看器：拖动圆形靶标以粗框定位窗口，查看并复制窗口、进程和控件信息；支持窗口操作、进程优先级、重启和终止。 |
| Caps+E | 打开原生快捷菜单，包含常用目录、系统设置和系统工具，并显示系统中可用的对应图标。 |
| Caps+R / Caps+Shift+R | 当前窗口居中 / 重置为 1000×800 后居中，按所在显示器缩放调整。 |
| Caps+T | 切换当前窗口置顶状态，并显示 Tooltip 提示。 |
| Caps+U / Caps+O | 鼠标左击 / 右击，穿透修饰键。 |
| Caps+I/J/K/L | 鼠标向上/左/下/右移动 1px，Shift 默认加速为 10px，穿透修饰键。 |
| Caps+P / Caps+Shift+P | 发送 Pause / 切换 ScrollLock。 |
| Caps+反斜杠 | 发送 ISO 反斜杠键，穿透修饰键。 |
| Caps+A / Caps+Shift+A | 切换 CapsLock / NumLock。 |
| Caps+S | 打开屏幕键盘。 |
| Caps+D / Caps+Shift+D | 显示桌面 / 最小化其他窗口。 |
| Caps+分号 / Caps+Shift+分号 | 行末添加分号 / 冒号。 |
| Caps+Enter / Caps+Shift+Enter | 当前行下方 / 上方插入新行。 |
| Caps+Z | 打字粘贴；临时关闭输入法的中文等输入模式，结束后恢复原状态。ASCII 发送键盘扫描码，非 ASCII 发送文本。 |
| Caps+X/C / Caps+Shift+X/C | 剪切/复制选区，Shift 处理当前整行。 |
| Caps+V / Caps+Shift+V | 纯文本粘贴 / 高级粘贴。高级粘贴处理 PDF 折行、网址域名和路径，路径直接转为正斜杠。 |
| Caps+B | 切换窗口穿透，再按一次恢复此前的窗口。 |
| Caps+Shift+B | 不透明度按 20%、40%、60%、80%、100% 循环；其他值恢复为 100%。 |
| Caps+逗号 / Caps+Shift+逗号 | 行末添加逗号 / 添加反斜杠并换行。 |
| Caps+. | 中文切换中英文标点，韩文发送汉字键，日文切换平假名。 |
| Caps+Shift+. | 日文切换片假名。 |
| Caps+Space / Caps+Shift+Space | 输入不间断空格 / 全角空格。 |
| Caps+滚轮 | 连续快速滚动，默认每格发送 5 格，倍率可设置。 |
| Caps+Shift+滚轮 | 连续横向滚动，上滚向左，下滚向右。 |
| Win+滚轮 | 调整前台窗口透明度，上滚增加不透明度，下滚降低不透明度。 |
| 任务栏上的滚轮 | 调整系统音量，支持主屏与副屏任务栏。 |

Layer、Alt、Shift 不限按下顺序；分层动作执行时临时释放系统侧修饰键，结束后恢复仍按住的修饰键。

`settings.json` 的 `Mouse.pointerFastStep` 设置 Shift 快速移动的物理像素步长（默认 `10`），`Mouse.wheelMultiplier` 设置 Caps+滚轮倍率（默认 `5`），均为正整数；修改后点击托盘“设置 → 重新读取配置”生效。

`PersonalScripts.launcherPath` 保存私人脚本库 [PersonalScripts](https://github.com/BH2WFR/PersonalScripts) 的 `run-script.ps1` 或 `run-script.py` 路径；为空或失效时从 PATH 查找并保存。外部工具复用 `Python.condaEnvironment`，按启动器所在目录拼接相对路径后直接运行目标脚本。

按住 Layer 时，除打开 GUI、菜单外的热键均可重复或交替触发，包括剪贴板、特殊空格、Anki 样式、滚动和缩放；GUI、菜单结束本次层，松开 Layer 前再次按功能键会被吸收，不会输入原字符。

Layer 未执行热键时，最后一个触发键松开即切换输入法语言；执行过穿透热键、连续滚轮、已消费或已取消的会话不再切换。

锁定键、窗口操作、大小写转换、整行复制/剪切、第二剪贴板、特殊换行及输入法模式等动作显示 Tooltip 提示，显示后自动消失。

窗口操作、系统 API 或剪贴板操作失败时，通过 Tooltip 显示原因并结束本次动作。

桌面、任务栏、通知中心和搜索等系统组件不执行窗口置顶、透明度调整或开启穿透。

屏幕键盘和窗口信息查看器按所在显示器的 DPI 缩放，跨屏移动时同步调整字体和布局。

第 3/4 层（Caps+Alt / Caps+Alt+Shift）：

| 按键 | 第 3 层 | 第 4 层 |
| --- | --- | --- |
| Tab | 强制插入制表符 | — |
| T | 根据剪贴板输入 `setName` | 根据剪贴板输入 `getName` |
| Enter | 强制插入 LF | 强制插入 CRLF |
| Z | 第二剪贴板打字粘贴，同样临时切英文并恢复 | — |
| X | 剪切到第二剪贴板 | 剪切当前行到第二剪贴板 |
| C | 复制到第二剪贴板 | 复制当前行到第二剪贴板 |
| V | 第二剪贴板纯文本粘贴 | 第二剪贴板高级粘贴 |

get/set 在剪贴板为空时仅显示警告，不输入文本。

第二剪贴板仅保存文本，使用时恢复系统剪贴板；文件管理器中普通剪切、复制和粘贴使用原生文件操作。第 3/4 层 Enter 沿用旧版分流，在表格、OneNote、终端、文件管理器和代码编辑器中发送 Alt+Enter。

Anki 中的 Layer 样式热键（Meta 对应 Win）：

| 按键 | Caps | Caps+Shift |
| --- | --- | --- |
| Q | 清除格式 | — |
| W | `sz_large` | — |
| E | `bg_yl` | `st_inv` |
| R | `bg_lm` | `bg_cy` |
| T | `bg_cy` | — |
| A | `cl_gy` | `cl_gn` |
| S | `cl_or` | `cl_bl` |
| D | `fg_or` | `fg_gy` |
| F | `fg_rd` | `fg_bl` |
| G | `fg_gn` | `fg_bl` |

非 Anki 窗口使用默认功能，没有默认功能则无动作；Anki 专用按键的空白层无动作，其他按键保留默认功能。`bg_gm` 尚未指定快捷键，不发送输入。

鼠标侧键按前台应用分流，执行后显示对应功能的简短 Tooltip：

| 应用 | XButton1（后退键） | XButton2（前进键） |
| --- | --- | --- |
| 默认 | Alt+Left | Alt+Right |
| Okular | Alt+Shift+Left | Alt+Shift+Right |
| Notion、Understand | 原始后退侧键 | 原始前进侧键 |
| 图片查看器 | 上一张 | 下一张 |
| CAD 类应用 | Esc | Enter |
| 思源笔记 | Ctrl+[ | Ctrl+] |
| 7-Zip、NanaZip、360 压缩、UltraISO、OneCommander | 上一级目录 | 无动作 |
| CAJ Viewer 7.x/8.x、PowerISO | 点击后退菜单或按钮 | 点击前进菜单或按钮 |
| 远程桌面、虚拟机 | 原始输入 | 原始输入 |

Shift+侧键在文件管理器及压缩工具中返回上级目录，在其他应用中发送原始侧键；Win+侧键向左/右切换虚拟桌面，Ctrl+侧键及 Ctrl+Shift+侧键暂留空。自动点击按目标显示器缩放换算，完成后恢复鼠标位置。

中键拖动：图片查看器、聊天软件的看图窗口及 Freeplane 中，按住中键模拟左键拖动；Photoshop、Illustrator、InDesign、Acrobat 等 Adobe 应用中，模拟空格＋左键拖动。

托盘顶层保留 F1、F2/F3/F4 映射、打开配置目录和重新读取配置，侧键映射、反转横向滚动等收在“其他设置”子菜单中；双击托盘图标打开 AHK 原生主窗口，可查看键盘历史和脚本信息。

托盘提供以下功能：

- 屏幕键盘：默认 512×197，无最小化按钮；单实例运行，重复启动将原窗口唤到鼠标附近并置前，限制在所在显示器的工作区内且不抢输入焦点。六行彩色布局，Layer 配合 Shift/Alt 使用四层热键，修饰键单击保留至下一次击键、长按锁定；“更多”和“数字”独立开关下方特殊键与右侧小键盘，可同时展开，锁定键底色和小键盘数字/导航标签随系统状态变化。
- F1 作为 Layer：切换并保存 F1 别名。
- 侧键映射：默认开启，切换后立即生效并保存；关闭时保留原始侧键输入。
- 输入法：中文切换可选 API、Ctrl+Space（默认）、Shift、小狼毫魔改 Ctrl+F20；韩文、日文可分别选择 API 或快捷键，默认使用韩/英键、Alt+反引号。中文标点可选 Ctrl+.（默认）或魔改 Ctrl+F21，各项选择立即生效并保存。
- 远程桌面/虚拟机：所有 Layer 触发键按远程设置发送 CapsLock、F1、F24 或使用本地 Layer，默认发送 F1，转发时保留修饰键。
- F2/F3/F4 鼠标映射：按住 F2 模拟中键，F3/F4 各滚动一格；每次启动默认关闭。
- 反转横向滚动、Win+滚轮调节前台窗口透明度：独立开关并保存。
- 开机启动：通过当前用户启动目录中的快捷方式启用或关闭。
- 重新读取配置：从 JSON 重新载入并立即应用设置，刷新菜单勾选。
- 重置钩子：释放模拟按键、取消当前 Layer 并重新安装键盘和鼠标钩子，保留当前开关和暂停状态。
- 暂停/恢复热键、打开配置目录、查看热键说明；保留 AHK 原生菜单，可通过 Open 查看键盘历史，通过 Window Spy 查看窗口信息，以及重载或退出脚本。

自定义“暂停热键”使用项目暂停图标，AHK 原生 Suspend/Pause 使用自带状态图标，恢复后显示项目图标。

启动时先检查管理员权限，未提权则申请管理员权限重启；随后读取 JSON 配置并定位指定的 Conda 环境，设置修改和退出时保存配置。Python 窗口按需启动，托盘图标区分启动中、运行和暂停状态。

远程桌面分类包含 Windows 远程桌面、ToDesk、RustDesk、向日葵、TeamViewer 和 AnyDesk；mstsc.exe 仅匹配 `TscShellContainerClass`，连接设置等其他窗口使用普通 Layer 行为。
