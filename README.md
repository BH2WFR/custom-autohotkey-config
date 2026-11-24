# Custom Autohotkey Config

一套 Windows 键盘 Layer 配置。按住一个键就能编辑文本、移动鼠标或操作窗口，单独轻按则在当前输入法中切换中/英、韩/英或日/英输入。[macOS 姊妹项目](https://github.com/BH2WFR/custom-karabiner-config)

## Layer 用法

下文的 `Caps` 代表任一启用的 Layer 键。CapsLock、F1、F24 默认全部启用，可在托盘「其他设置 → Layer 键设置」分别开关，实体键盘和屏幕键盘共用设置。已在系统中将 CapsLock 映射为 F24 时，用 F24 开关控制该键。

按住 Layer 可连续使用热键。加 Shift、Alt 或 Alt+Shift 分别进入第 2、3、4 层，按键顺序不限。打开工具窗口或菜单后，松开 Layer 再开始下一组操作。

## 常用热键

| 热键 | 功能 |
| --- | --- |
| Caps+反引号 | 释放修饰键和本次 Layer 键。 |
| Caps+1 / Caps+2 | 查看前台窗口及按键状态 / 查看当前层号和触发键，四层均可用。 |
| Caps+4 | 用 `${` 和 `}` 包住选中文本。 |
| Caps+5 / Caps+Shift+5 | 创建可移动、可调整大小的实心 / 空心屏幕遮挡。 |
| Caps+6 / Caps+Shift+6 | 选中文本转小写 / 大写。 |
| Caps+7 | 选区内每个单词首字母大写，其余字母小写。 |
| Caps+- / Caps+= | 在鼠标指针处缩小 / 放大视图。加 Shift 则向左 / 右滚动。 |
| Caps+Backspace / Caps+Shift+Backspace | 删除二字词的第一个字 / 删除当前行。 |
| Caps+Tab / Caps+Shift+Tab | 将当前行或多行选区缩进 / 取消缩进，缩进宽度为四个空格。 |
| Caps+Q | 发送 Esc，保留修饰键，例如 Ctrl+Caps+Q 发送 Ctrl+Esc。 |
| Caps+W | 查看当前窗口、控件和所属进程。 |
| Caps+E | 打开常用目录、系统设置和系统工具菜单。 |
| Caps+R / Caps+Shift+R | 将窗口居中 / 重置为 1000×800 后居中。 |
| Caps+T | 切换当前窗口置顶。 |
| Caps+Y / Caps+Shift+Y | 复制选区，在文本/路径变换工具中处理，或在 Unicode 字符查看器中查看。 |
| Caps+U / Caps+O | 鼠标左击 / 右击，保留修饰键。 |
| Caps+I/J/K/L | 向上/左/下/右移动指针 1 像素，保留修饰键。按住 Shift 可加速，默认每次 10 像素。 |
| Caps+P / Caps+Shift+P | 发送 Pause / 切换 ScrollLock。 |
| Caps+反斜杠 | 发送 ISO 反斜杠键，保留修饰键。 |
| Caps+A / Caps+Shift+A | 切换 CapsLock / NumLock。 |
| Caps+S | 打开或唤回屏幕键盘，保留原窗口的输入焦点。 |
| Caps+D / Caps+Shift+D | 显示桌面 / 最小化其他窗口。 |
| Caps+分号 / Caps+Shift+分号 | 在行末添加分号 / 冒号。 |
| Caps+Enter / Caps+Shift+Enter | 在当前行下方 / 上方插入新行。 |
| Caps+Z | 逐字输入剪贴板文本，结束后恢复输入法状态。 |
| Caps+X / Caps+C | 剪切 / 复制选区，加 Shift 处理当前整行。 |
| Caps+V / Caps+Shift+V | 粘贴纯文本 / 高级粘贴。高级粘贴可合并 PDF 折行、提取网址域名，或将路径转为正斜杠。 |
| Caps+B | 置顶当前窗口并让鼠标点击穿过它，已有透明度会保留，原本完全不透明时使用设定的不透明度（默认 59%）。再次按下取消置顶和穿透，恢复完全不透明。 |
| Caps+Shift+B | 窗口不透明度在 20%、40%、60%、80%、100% 间循环，其他值先恢复为 100%。 |
| Caps+逗号 / Caps+Shift+逗号 | 在行末添加逗号 / 添加反斜杠并换行。 |
| Caps+. / Caps+Shift+. | 中文切换中英文标点，韩文发送汉字键，日文切换平假名。加 Shift 可切换日文片假名。 |
| Caps+Space / Caps+Shift+Space | 输入不间断空格 / 全角空格。 |

## 第 3、4 层

第二剪贴板可单独存一份文本，保留系统剪贴板原有内容。文件管理器中的普通剪切、复制和粘贴仍可操作文件。

| 按键 | Caps+Alt | Caps+Alt+Shift |
| --- | --- | --- |
| Tab | 插入制表符 | — |
| T | 用剪贴板文本生成 `setName` | 用剪贴板文本生成 `getName` |
| Enter | 插入 LF 换行 | 插入 CRLF 换行 |
| Z | 逐字输入第二剪贴板文本 | — |
| X | 剪切选区到第二剪贴板 | 剪切当前行到第二剪贴板 |
| C | 复制选区到第二剪贴板 | 复制当前行到第二剪贴板 |
| V | 粘贴第二剪贴板文本 | 对第二剪贴板使用高级粘贴 |

在 Excel、OneNote 以及支持的终端、文件管理器和代码编辑器中，这两层的 Enter 均发送 Alt+Enter。

## Anki 样式

在 Anki 中，下列按键使用专用样式绑定，空白层无动作，其余按键沿用通用热键。

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

## 鼠标

| 操作 | 功能 |
| --- | --- |
| Caps+滚轮 | 快速滚动，默认每格滚动 5 格。 |
| Caps+Shift+滚轮 | 横向滚动，每次一格，默认上滚向左、下滚向右。 |
| Win+滚轮 | 调整前台窗口透明度，上滚更不透明，下滚更透明。 |
| 在任务栏上滚动 | 调整系统音量，主屏和副屏均可用。 |
| 中键拖动 | 在图片查看器、聊天看图窗口、Freeplane 和 Photoshop 等 Adobe 应用中拖动画布或图像。 |
| Win+后退 / 前进侧键 | 切换到左侧 / 右侧虚拟桌面。 |

侧键默认按前台应用执行以下操作。按住 Shift 使用原始侧键，在支持的文件管理器和压缩工具中则返回上一级目录。

| 应用 | 后退侧键 | 前进侧键 |
| --- | --- | --- |
| 默认（含 Anki） | Alt+Left | Alt+Right |
| Okular | Alt+Shift+Left | Alt+Shift+Right |
| Notion、Understand、远程桌面及虚拟机 | 原始后退键 | 原始前进键 |
| 图片查看器 | 上一张 | 下一张 |
| CAD 类应用 | Esc | Enter |
| 思源笔记 | Ctrl+[ | Ctrl+] |
| 7-Zip、NanaZip、360 压缩、UltraISO、OneCommander | 上一级目录 | — |
| CAJ Viewer 7.x/8.x、PowerISO | 后退 | 前进 |

## 托盘与远程桌面

- 「其他设置」可调整指针步长、滚动倍率和穿透不透明度，开关侧键映射及 Win+滚轮调透明度，或反转横向滚动。输入法切换方式、Conda 环境和私人脚本库启动器也可在此选择。
- 远程桌面或虚拟机中，Layer 默认向远端发送 F1 并保留修饰键。可在「其他设置」改发 CapsLock、F24 或使用本地 Layer。
- 需要用键盘代替鼠标时，可临时开启 F2 中键、F3 向上滚动、F4 向下滚动。每次启动默认关闭。
- 「其他工具」可打开键盘映射编辑器、系统事件查看器、图片文字与公式识别、矩阵查看器、`rclone-sync` 和脚本启动器等。[PersonalScripts](https://github.com/BH2WFR/PersonalScripts)
- 托盘还可设置开机启动、暂停或恢复热键、打开配置目录并重新读取设置。热键失灵时可用「重置钩子」恢复输入。
