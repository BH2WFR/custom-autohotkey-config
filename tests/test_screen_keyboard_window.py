"""使用实际 Tk/Win32 窗口验证键盘尺寸及置顶层级，无键鼠输入。"""
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import sys
import tkinter as tk
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "py"))
from gui.screen_keyboard import DEFAULT_SIZE, ScreenKeyboard
from utils.nonactivating_window import GWL_STYLE, WS_MINIMIZEBOX, U

U.GetWindow.argtypes = [W.HWND, W.UINT]
U.GetWindow.restype = W.HWND
GW_HWNDPREV = 3


class WindowTest:
    def __init__(self):
        self.keyboard = ScreenKeyboard(0)
        self.other = tk.Toplevel(self.keyboard.window)
        self.other.title("Keyboard topmost regression")
        self.other.geometry("560x230+60+60")
        self.other.attributes("-topmost", True)
        self.error = None
        self.keyboard.window.after(150, self.check)

    def check(self):
        keyboard = self.keyboard
        try:
            assert (keyboard.window.winfo_width(), keyboard.window.winfo_height()) == DEFAULT_SIZE
            assert len(keyboard.toolbar) == 3
            assert not U.GetWindowLongPtrW(keyboard.native.hwnd, GWL_STYLE) & WS_MINIMIZEBOX
            assert not hasattr(keyboard, "minimize")
            other_hwnd = U.GetAncestor(self.other.winfo_id(), 2)
            foreground = U.GetForegroundWindow()
            for _ in range(3):
                self.other.lift()
                keyboard.native.show()
                above = U.GetWindow(keyboard.native.hwnd, GW_HWNDPREV)
                while above:
                    assert above != other_hwnd, "Keyboard remains behind an existing topmost window"
                    above = U.GetWindow(above, GW_HWNDPREV)
                assert U.GetForegroundWindow() == foreground, "Keyboard raise changes input focus"
            keyboard.expanded = True
            keyboard.reset_size()
            keyboard.window.update_idletasks()
            assert not keyboard.expanded
            assert (keyboard.window.winfo_width(), keyboard.window.winfo_height()) == DEFAULT_SIZE
            print("PASS: default/reset size, no minimize button, repeated raise above topmost without changing focus")
        except Exception:
            self.error = traceback.format_exc()
        finally:
            keyboard.closing = True
            self.other.destroy()
            keyboard.native.close()
            keyboard.window.destroy()

    def run(self):
        self.keyboard.run()
        if self.error:
            raise AssertionError(self.error)


if __name__ == "__main__":
    WindowTest().run()
