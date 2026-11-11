"""真实鼠标点击 Tk 键盘，经 IPC 和 AHK 分发后在独立 Edit 中验证输入。"""
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import sys
import traceback
import faulthandler

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "py"))
from gui.screen_keyboard import ScreenKeyboard
from gui.keyboard_layout import DEFAULT_SIZE
from utils.keyboard_state import LockKeyState
from utils.nonactivating_window import U

U.SetCursorPos.argtypes = [C.c_int, C.c_int]
U.mouse_event.argtypes = [W.DWORD, W.DWORD, W.DWORD, W.DWORD, C.c_size_t]
U.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.SendMessageW.restype = W.LPARAM
U.SetForegroundWindow.argtypes = [W.HWND]
U.IsWindowVisible.argtypes = [W.HWND]
U.IsIconic.argtypes = [W.HWND]
MOUSE_DOWN, MOUSE_UP = 0x0002, 0x0004
WM_GETTEXT, WM_GETTEXTLENGTH = 0x000D, 0x000E


class DesktopTest:
    def __init__(self):
        self.edit = int(sys.argv[2])
        self.output = Path(sys.argv[3])
        self.target = U.GetForegroundWindow()
        self.cursor = W.POINT()
        U.GetCursorPos(C.byref(self.cursor))
        self.keyboard = ScreenKeyboard(int(sys.argv[1]))
        self.keyboard.window.geometry("%dx%d+80+360" % DEFAULT_SIZE)
        self.expected = ""
        self.sent = []
        original_send = self.keyboard.client.send
        def record(*args):
            self.sent.append(args)
            original_send(*args)
        self.keyboard.client.send = record
        self.count = 0
        self.steps = self.scenarios()
        self.keyboard.window.after(500, self.next)

    def text(self, hwnd=None):
        hwnd = self.edit if hwnd is None else hwnd
        length = U.SendMessageW(hwnd, WM_GETTEXTLENGTH, 0, 0)
        buffer = C.create_unicode_buffer(length + 1)
        U.SendMessageW(hwnd, WM_GETTEXT, len(buffer), C.addressof(buffer))
        return buffer.value

    def check(self, text):
        self.expected += text
        actual = self.text()
        assert actual == self.expected, (actual, self.expected, self.keyboard.window.state(),
                                        self.keyboard.window.winfo_ismapped(), self.keyboard.pressed,
                                        U.GetForegroundWindow(), self.target, self.keyboard.native.hwnd,
                                        self.sent, self.keyboard.window.geometry(),
                                        [(b.winfo_rootx(), b.winfo_rooty(), b.winfo_width(), b.winfo_height()) for b in [self.keyboard.buttons['b']]])
        assert U.GetForegroundWindow() == self.target, "Keyboard stole target focus"
        self.count += 2

    def click(self, key, duration=60):
        button = (self.keyboard.buttons.get(key) or self.keyboard.toolbar_buttons.get(key)
                  or self.keyboard.numpad_buttons.get(key)
                  or self.keyboard.extended_buttons[key])
        U.SetCursorPos(button.winfo_rootx() + button.winfo_width() // 2,
                       button.winfo_rooty() + button.winfo_height() // 2)
        U.mouse_event(MOUSE_DOWN, 0, 0, 0, 0)
        yield duration
        U.mouse_event(MOUSE_UP, 0, 0, 0, 0)
        yield 160

    def scenarios(self):
        assert U.GetForegroundWindow() == self.target, ("Focus stolen before click", U.GetForegroundWindow(), self.target, self.keyboard.native.hwnd)
        assert self.keyboard.status.cget('text') == '普通输入', "Status must not display a foreground title"
        yield from self.click("b")
        self.check("b")
        yield from self.switch_windows()
        if len(sys.argv) > 5 and sys.argv[5] == "--switch-only":
            return
        yield from self.click("LShift")
        yield from self.click("b")
        self.check("B")
        for mods, marker in [((), "[1]"), (("LShift",), "[2]"),
                             (("LAlt",), "[3]"), (("LAlt", "LShift"), "[4]")]:
            if len(mods) == 2:
                yield from self.click("Layer")
            for key in mods:
                yield from self.click(key)
            if len(mods) != 2:
                yield from self.click("Layer")
            yield from self.click("2")
            self.check(marker)
            assert not self.keyboard.held
        yield from self.click("Layer", 600)
        yield from self.click("2")
        yield from self.click("2")
        self.check("[1][1]")
        yield from self.click("e")
        yield from self.click("e")
        self.check("[once]")
        yield from self.click("Layer")
        yield from self.click("Layer")
        yield from self.click("a")
        self.check("[app]")
        yield from self.click("LControl")
        yield from self.click("Layer")
        yield from self.click("q")
        self.check("[ctrl]")
        yield from self.click("Layer")
        yield from self.click("Layer")
        self.check("[tap]")
        yield from self.click("Layer", 600)
        U.SendMessageW(self.keyboard.native.hwnd, 0x8001, 0, 0)
        yield 150
        assert not self.keyboard.held and not self.keyboard.locked, "Host reset clears latched keys"
        self.count += 1

        yield from self.click("language")
        self.check("[tap]")
        yield from self.numpad()

    def numpad(self):
        yield from self.click("extended")
        yield 300
        if not LockKeyState.read()["NumLock"]:
            yield from self.click("NumLock")
            yield 300
        keyboard = self.keyboard
        assert keyboard.numpad_buttons["Numpad7"].cget("text") == "7"
        assert keyboard.numpad_buttons["NumLock"].cget("background") == keyboard.LOCK_ON_BACKGROUND
        for key, text in [("Numpad1", "1"), ("NumpadAdd", "+"), ("Numpad2", "2")]:
            yield from self.click(key)
            self.check(text)
        yield from self.click("NumLock")
        yield 300
        assert not LockKeyState.read()["NumLock"]
        assert keyboard.numpad_buttons["Numpad7"].cget("text") == "Home"
        assert keyboard.numpad_buttons["NumpadDot"].cget("text") == "Del"
        yield from self.click("Numpad4")
        yield from self.click("NumpadDot")
        self.expected = self.expected[:-1]
        self.check("")
        self.count += 5
        # 外部改变锁定键，界面无需点击便同步。
        before = LockKeyState.read()["ScrollLock"]
        keyboard.client.send("key", (), "ScrollLock")
        keyboard.client.send("key", (), "NumLock")
        yield 400
        assert keyboard.lock_states["ScrollLock"] != before
        color = keyboard.extended_buttons["ScrollLock"].cget("background")
        assert (color == keyboard.LOCK_ON_BACKGROUND) == keyboard.lock_states["ScrollLock"]
        assert keyboard.numpad_buttons["Numpad7"].cget("text") == "7"
        self.count += 3
        self.capture("screen-keyboard-extended.png")
        yield from self.click("extended")
        assert keyboard.lock_timer is None
        assert not keyboard.numpad_buttons["NumLock"].winfo_ismapped()
        self.count += 2

    def switch_windows(self):
        for hwnd in [int(sys.argv[4]), self.target] * 3:
            assert U.SetForegroundWindow(hwnd), "Cannot activate the other test window"
            yield 200
            assert U.GetForegroundWindow() == hwnd, "Target did not remain active"
            assert U.IsWindowVisible(self.keyboard.native.hwnd), "Keyboard hidden on target switch"
            assert not U.IsIconic(self.keyboard.native.hwnd), "Keyboard minimized on target switch"
            assert U.GetWindowLongPtrW(self.keyboard.native.hwnd, -20) & 0x8, "Keyboard lost topmost state"
            self.count += 4
        yield from self.click("Layer", 600)
        assert U.SetForegroundWindow(int(sys.argv[4]))
        yield 200
        yield from self.click("2")
        assert self.text(int(sys.argv[6])) == "2", "Old Layer state carried into the new target"
        assert not self.keyboard.held and not self.keyboard.locked
        assert U.SetForegroundWindow(self.target)
        yield 200
        yield from self.click("2")
        self.check("2")
        self.count += 2
        self.capture("screen-keyboard.png")
        yield from self.click("extended")
        assert self.keyboard.extended_buttons["PrintScreen"].winfo_ismapped()
        self.count += 1
        self.capture("screen-keyboard-extended.png")
        self.keyboard.reset_size()
        yield 150
        assert not self.keyboard.extended_buttons["PrintScreen"].winfo_ismapped()
        self.count += 1

    def capture(self, filename):
        from PIL import ImageGrab
        rect = W.RECT()
        U.GetWindowRect.argtypes = [W.HWND, C.POINTER(W.RECT)]
        U.GetWindowRect(self.keyboard.native.hwnd, C.byref(rect))
        ImageGrab.grab(bbox=(rect.left, rect.top, rect.right, rect.bottom), all_screens=True).save(self.output.parent / filename)

    def next(self):
        try:
            delay = next(self.steps)
        except StopIteration:
            self.finish(f"PASS: {self.count} native screen keyboard assertions\n")
        except Exception:
            self.finish(traceback.format_exc())
        else:
            self.keyboard.window.after(delay, self.next)

    def finish(self, result):
        U.mouse_event(MOUSE_UP, 0, 0, 0, 0)
        U.SetCursorPos(self.cursor.x, self.cursor.y)
        self.output.write_text(result, encoding="utf-8")
        self.keyboard.close()


if __name__ == "__main__":
    fault_log = Path(sys.argv[3]).with_suffix('.fault.log').open('w', encoding='utf-8')
    faulthandler.enable(fault_log)
    try:
        test = DesktopTest()
        test.keyboard.run()
    except Exception:
        Path(sys.argv[3]).write_text(traceback.format_exc(), encoding="utf-8")
        raise
