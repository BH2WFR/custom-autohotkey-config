"""通过原生拖拽边界消息验证真实 Tk 控件只在调整结束后布局。"""
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import sys
import traceback
from threading import Thread
from time import sleep

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "py"))
from gui.screen_keyboard import ScreenKeyboard
from utils.dpi_window import DpiWindow, WM_DPICHANGED
from utils.nonactivating_window import U, WM_ENTERSIZEMOVE, WM_EXITSIZEMOVE

U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM
U.SetCursorPos.argtypes = [C.c_int, C.c_int]
U.mouse_event.argtypes = [W.DWORD, W.DWORD, W.DWORD, W.DWORD, C.c_size_t]


class ResizeTest:
    def __init__(self):
        self.keyboard = ScreenKeyboard(0)
        self.error = None
        self.layouts = 0
        original_place = self.keyboard.buttons["Esc"].place
        def place(*args, **kwargs):
            self.layouts += 1
            return original_place(*args, **kwargs)
        self.keyboard.buttons["Esc"].place = place
        self.steps = self.scenarios()
        self.keyboard.window.after(250, self.next)

    def scenarios(self):
        keyboard = self.keyboard
        root, native = keyboard.window, keyboard.native
        initial_width, initial_height = root.winfo_width(), root.winfo_height()
        for delta in (80, -80):
            self.layouts = 0
            signature = keyboard.layout_signature
            U.SendMessageW(native.hwnd, WM_ENTERSIZEMOVE, 0, 0)
            assert native.is_resizing
            for step in range(1, 6):
                root.geometry(f"{initial_width + delta * step // 5}x{initial_height + delta * step // 10}")
                root.update_idletasks()
                yield 50
                assert self.layouts == 0, "Controls were laid out while the sizing loop was active"
                assert keyboard.layout_signature == signature
            U.SendMessageW(native.hwnd, WM_EXITSIZEMOVE, 0, 0)
            yield 250
            assert not native.is_resizing
            assert self.layouts == 1, ("Final size must be laid out exactly once", self.layouts)
            assert keyboard.layout_signature[:2] == (root.winfo_width(), root.winfo_height())
        self.layouts = 0
        U.SendMessageW(native.hwnd, WM_ENTERSIZEMOVE, 0, 0)
        U.SendMessageW(native.hwnd, WM_EXITSIZEMOVE, 0, 0)
        yield 250
        assert self.layouts == 0, "Moving without resizing should not reflow controls"
        keyboard.toggle_extended()
        assert self.layouts == 1, "Toolbar resize should still update immediately"
        yield from self.external_changes()
        if "--native" in sys.argv:
            yield from self.native_drag()
        print("PASS: resizing defers layout, release applies once, unchanged size skips layout, toolbar remains immediate")

    def external_changes(self):
        keyboard = self.keyboard
        native, root = keyboard.native, keyboard.window
        rect = W.RECT()
        U.GetWindowRect(native.hwnd, C.byref(rect))
        self.layouts = 0
        # 直接调用 Win32 改变外框，不经过 Tk.geometry，也没有鼠标拖拽结束消息。
        U.SetWindowPos(native.hwnd, None, 0, 0, rect.right - rect.left + 120,
                       rect.bottom - rect.top + 60, 0x0016)
        yield 200
        assert not native.is_resizing and self.layouts == 1, "External resize did not refresh immediately"
        assert keyboard.layout_signature[:2] == (root.winfo_width(), root.winfo_height())
        keyboard.reset_size()
        root.geometry("1100x600")
        root.update_idletasks()
        U.GetWindowRect(native.hwnd, C.byref(rect))
        initial_size = root.winfo_width(), root.winfo_height()
        # 即使外框完全不变，显示器 DPI 通知也必须更新字体和控件。
        original_dpi = native.dpi
        for dpi in (144 if original_dpi != 144 else 192, original_dpi):
            self.layouts = 0
            U.SendMessageW(native.hwnd, WM_DPICHANGED, dpi | (dpi << 16), C.addressof(rect))
            yield 250
            assert keyboard.scale == dpi / 96
            assert self.layouts > 0, "DPI-only change was incorrectly skipped by the layout cache"
            assert (root.winfo_width(), root.winfo_height()) == initial_size
            font = root.tk.splitlist(keyboard.status.cget("font"))
            assert int(font[1]) == -round(8 * dpi / 72)
        keyboard.reset_size()
        root.update_idletasks()
        print("PASS: external Win32 resize and DPI-only changes refresh without a mouse-release notification")

    def native_drag(self):
        keyboard = self.keyboard
        cursor, rect = W.POINT(), W.RECT()
        U.GetCursorPos(C.byref(cursor))
        U.GetWindowRect(keyboard.native.hwnd, C.byref(rect))
        self.layouts = 0
        self.drag_error = None
        def drag():
            DpiWindow.enable()
            try:
                assert U.SetCursorPos(rect.right - 3, rect.bottom - 3), "Input desktop unavailable"
                U.mouse_event(0x0002, 0, 0, 0, 0)
                sleep(0.2)
                assert keyboard.native.is_resizing, "Native border drag did not start"
                for offset in (15, 30, 45, 60):
                    U.SetCursorPos(rect.right - 3 + offset, rect.bottom - 3 + offset)
                    sleep(0.1)
                    assert self.layouts == 0, "Native mouse drag triggered an intermediate layout"
            except Exception:
                self.drag_error = traceback.format_exc()
            finally:
                U.mouse_event(0x0004, 0, 0, 0, 0)
                U.SetCursorPos(cursor.x, cursor.y)
        worker = Thread(target=drag, daemon=True)
        worker.start()
        while worker.is_alive():
            yield 100
        yield 250
        assert not self.drag_error, self.drag_error
        assert not keyboard.native.is_resizing and self.layouts == 1, (keyboard.native.is_resizing, self.layouts)
        print("PASS: actual mouse border drag performs zero intermediate layouts and one layout on release")

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
    ResizeTest().run()
