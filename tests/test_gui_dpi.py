"""真实 Windows 窗口跨屏与 DPI 消息测试，不改变显示器设置或输入焦点。"""
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import sys
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "py"))
from gui.screen_keyboard import ScreenKeyboard, DEFAULT_SIZE
from utils.dpi_window import U, WM_DPICHANGED
from utils.nonactivating_window import MonitorInfo

MONITORPROC = C.WINFUNCTYPE(W.BOOL, W.HANDLE, W.HDC, C.POINTER(W.RECT), W.LPARAM)
U.EnumDisplayMonitors.argtypes = [W.HDC, C.POINTER(W.RECT), MONITORPROC, W.LPARAM]
U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM
U.AdjustWindowRectExForDpi.argtypes = [C.POINTER(W.RECT), W.DWORD, W.BOOL, W.DWORD, W.UINT]


class DpiTest:
    def __init__(self):
        self.keyboard = ScreenKeyboard(0)
        self.error = None
        self.monitors = []
        def collect(handle, dc, rect, data):
            info = MonitorInfo(size=C.sizeof(MonitorInfo))
            U.GetMonitorInfoW(handle, C.byref(info))
            self.monitors.append((info.work.left, info.work.top))
            return True
        U.EnumDisplayMonitors(None, None, MONITORPROC(collect), 0)
        self.steps = self.scenarios()
        self.keyboard.window.after(300, self.next)

    def check(self, dpi):
        keyboard = self.keyboard
        assert keyboard.scale == dpi / 96, (keyboard.scale, dpi)
        expected = tuple(round(value * dpi / 96) for value in DEFAULT_SIZE)
        actual = (keyboard.window.winfo_width(), keyboard.window.winfo_height())
        assert all(abs(a - b) <= 2 for a, b in zip(actual, expected)), (actual, expected, dpi)
        assert keyboard.window.minsize() == (keyboard.px(426), keyboard.px(166))
        font = keyboard.window.tk.splitlist(keyboard.status.cget("font"))
        assert int(font[1]) == -round(8 * dpi / 72), font
        language = keyboard.buttons["language"]
        assert language.winfo_height() > abs(int(font[1]))

    def scenarios(self):
        keyboard = self.keyboard
        seen = set()
        for x, y in self.monitors + list(reversed(self.monitors)):
            U.SetWindowPos(keyboard.native.hwnd, None, x + 60, y + 60, 0, 0, 0x0015)
            yield 350
            dpi = U.GetDpiForWindow(keyboard.native.hwnd)
            seen.add(dpi)
            self.check(dpi)
        print(f"Native monitor moves: {len(self.monitors)} displays, DPI {sorted(seen)}")
        for dpi in (96, 120, 144, 192, 240, 96):
            rect = W.RECT(0, 0, round(DEFAULT_SIZE[0] * dpi / 96), round(DEFAULT_SIZE[1] * dpi / 96))
            style = U.GetWindowLongPtrW(keyboard.native.hwnd, -16)
            exstyle = U.GetWindowLongPtrW(keyboard.native.hwnd, -20)
            # 测试消息中的建议外框保持当前系统非客户区，隔离控件缩放路径。
            actual_dpi = U.GetDpiForWindow(keyboard.native.hwnd)
            U.AdjustWindowRectExForDpi(C.byref(rect), style, False, exstyle, actual_dpi)
            x, y = self.monitors[0]
            bounds = W.RECT(x + 60, y + 60, x + 60 + rect.right - rect.left, y + 60 + rect.bottom - rect.top)
            U.SendMessageW(keyboard.native.hwnd, WM_DPICHANGED, dpi | (dpi << 16), C.addressof(bounds))
            yield 250
            self.check(dpi)
            keyboard.toggle_extended()
            keyboard.toggle_numpad()
            keyboard.window.update_idletasks()
            assert keyboard.numpad_buttons["NumpadEnter"].winfo_height() > keyboard.buttons["Enter"].winfo_height()
            keyboard.toggle_extended()
            keyboard.toggle_numpad()
            keyboard.window.update_idletasks()
            self.check(dpi)
        print("PASS: 100/125/150/200/250% DPI messages, fonts, panel toggles and round-trip sizes")

    def next(self):
        try:
            delay = next(self.steps)
        except StopIteration:
            self.finish()
        except Exception:
            self.error = traceback.format_exc()
            self.finish()
        else:
            self.keyboard.window.after(delay, self.next)

    def finish(self):
        self.keyboard.closing = True
        self.keyboard.stop_lock_updates()
        self.keyboard.native.close()
        self.keyboard.window.destroy()

    def run(self):
        self.keyboard.run()
        if self.error:
            raise AssertionError(self.error)


if __name__ == "__main__":
    DpiTest().run()
