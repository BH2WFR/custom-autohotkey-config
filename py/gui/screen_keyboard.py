"""不抢占焦点的 Windows 屏幕键盘。"""

from pathlib import Path
import tkinter as tk
from tkinter import messagebox

from gui.keyboard_layout import (DEFAULT_SIZE, EXTENDED_KEYS, MINIMUM_SIZE, MODIFIERS,
                                 NUMPAD_KEYS, NUMPAD_NAVIGATION, ROWS, ROW_UNITS, STICKY_KEYS, key_color)
from utils.keyboard_client import KeyboardClient
from utils.keyboard_state import LockKeyState
from utils.nonactivating_window import NonactivatingWindow


class ScreenKeyboard:
    LOCK_DELAY = 500
    REPEAT_DELAY = 450
    REPEAT_INTERVAL = 45
    BACKGROUND = "#f1f3f5"
    LOCKED_BACKGROUND = "#7a202a"
    LOCKED_TEXT = "#ffe160"
    DARK_KEY_PRESSED_BACKGROUND = "#99db9d"
    UI_FONT = "Microsoft YaHei UI"
    KEY_FONT = "Segoe UI"
    LOCK_STATE_INTERVAL = 250
    LOCK_ON_BACKGROUND = "#185337"
    EXTRA_ROW_HEIGHT = 30
    NUMPAD_COLUMNS = 4
    NUMPAD_ROWS = 5
    MARGIN = 4
    GAP = 3

    def __init__(self, host: int) -> None:
        self.target = NonactivatingWindow.foreground()
        self.window = tk.Tk()
        self.window.withdraw()
        self.window.title("屏幕键盘 — Custom Autohotkey Config")
        self.window.geometry("%dx%d" % DEFAULT_SIZE)
        self.window.minsize(*MINIMUM_SIZE)
        self.window.configure(background=self.BACKGROUND)
        self.window.iconbitmap(str(Path(__file__).resolve().parents[2] / "res" / "MainIcon.ico"))
        self.held = set()
        self.locked = set()
        self.pressed = None
        self.timer = None
        self.expanded = False
        self.closing = False
        self.lock_states = LockKeyState.read()
        self.lock_timer = None
        self.buttons = {}
        self.extended_buttons = {}
        self.numpad_buttons = {}
        self.status = tk.Label(self.window, anchor="w", background=self.BACKGROUND,
                               foreground="#505760", font=(self.UI_FONT, 8))
        self.toolbar = []
        self.toolbar_buttons = {}
        for name, label, action in [("extended", "更多", self.toggle_extended),
                                    ("reset", "释放", self.reset),
                                    ("size", "复位", self.reset_size)]:
            button = tk.Label(self.window, text=label, background=self.BACKGROUND,
                               font=(self.UI_FONT, 8), cursor="hand2")
            button.bind("<ButtonRelease-1>", lambda event, fn=action: self.perform(fn))
            self.toolbar.append(button)
            self.toolbar_buttons[name] = button
        for row in ROWS:
            for name, label, units in row:
                self.buttons[name] = self.make_button(name, label)
        for name, label in EXTENDED_KEYS:
            self.extended_buttons[name] = self.make_button(name, label)
        for name, label, *_ in NUMPAD_KEYS:
            self.numpad_buttons[name] = self.make_button(name, label)
        self.window.bind("<Configure>", self.layout)
        self.window.bind("<ButtonRelease-1>", self.release_pointer)
        self.window.bind("<Unmap>", self.unmapped)
        self.window.protocol("WM_DELETE_WINDOW", self.close)
        self.native = NonactivatingWindow(self.window, lambda: self.perform(self.reset))
        self.client = KeyboardClient(host, self.native.hwnd)
        self.layout()
        self.refresh()
        self.native.show()

    def make_button(self, name, label):
        button = tk.Label(self.window, text=label, background=key_color(name),
                           foreground="white" if name == "language" else "#202124",
                           borderwidth=1, relief="solid", font=(self.UI_FONT if name == "language" else self.KEY_FONT, 9), cursor="arrow")
        button.bind("<ButtonPress-1>", lambda event: self.perform(lambda: self.press(name)))
        return button

    def perform(self, action):
        try:
            action()
        except Exception as exc:
            self.cancel_timer()
            self.held.clear()
            self.locked.clear()
            self.refresh()
            messagebox.showerror("屏幕键盘", str(exc), parent=self.window)

    def send(self, command, key=""):
        if key in NUMPAD_NAVIGATION and not LockKeyState.read()["NumLock"]:
            key = NUMPAD_NAVIGATION[key][0]
        self.client.send(command, sorted(self.held & MODIFIERS), key)

    def press(self, name):
        self.check_target()
        self.cancel_timer()
        self.pressed = name
        if name == "language":
            self.language()
            self.pressed = name
        elif name in STICKY_KEYS:
            if name in self.held:
                self.held.remove(name)
                self.locked.discard(name)
                if name == "Layer":
                    self.send("end")
            else:
                self.held.add(name)
                if name == "Layer":
                    self.send("begin")
                self.timer = self.window.after(self.LOCK_DELAY, lambda: self.lock(name))
        else:
            self.send("key", name)
            if name not in LockKeyState.KEYS:
                self.timer = self.window.after(self.REPEAT_DELAY, lambda: self.repeat(name))
        self.refresh()

    def repeat(self, name):
        self.timer = None
        self.check_target()
        if self.pressed == name:
            self.perform(lambda: self.send("key", name))
            self.timer = self.window.after(self.REPEAT_INTERVAL, lambda: self.repeat(name))

    def lock(self, name):
        self.timer = None
        if self.pressed == name and name in self.held:
            self.locked.add(name)
            self.refresh()

    def release_pointer(self, event=None):
        self.cancel_timer()
        name, self.pressed = self.pressed, None
        if name and name not in STICKY_KEYS:
            self.perform(self.release_once)
        self.refresh()

    def release_once(self):
        if "Layer" in self.held and "Layer" not in self.locked:
            self.send("end")
        self.held.intersection_update(self.locked)

    def cancel_timer(self):
        if self.timer is not None:
            self.window.after_cancel(self.timer)
            self.timer = None

    def reset(self):
        self.cancel_timer()
        self.pressed = None
        self.send("reset")
        self.held.clear()
        self.locked.clear()
        self.refresh()

    def language(self):
        self.reset()
        self.send("begin")
        self.send("end")

    def check_target(self):
        target = NonactivatingWindow.foreground()
        if target != self.target:
            self.target = target
            self.reset()

    def unmapped(self, event):
        if event.widget is self.window and hasattr(self, "client") and not self.closing:
            self.perform(self.reset)

    def reset_size(self):
        self.expanded = False
        self.stop_lock_updates()
        self.window.minsize(*MINIMUM_SIZE)
        self.window.geometry("%dx%d" % DEFAULT_SIZE)

    def toggle_extended(self):
        self.expanded = not self.expanded
        ratio = (ROW_UNITS + self.NUMPAD_COLUMNS) / ROW_UNITS
        width = self.window.winfo_width() - self.MARGIN * 2 + self.GAP
        width = round(width * ratio if self.expanded else width / ratio) + self.MARGIN * 2 - self.GAP
        height = self.window.winfo_height() + (self.EXTRA_ROW_HEIGHT if self.expanded else -self.EXTRA_ROW_HEIGHT)
        self.window.minsize(round(MINIMUM_SIZE[0] * ratio) if self.expanded else MINIMUM_SIZE[0],
                            MINIMUM_SIZE[1] + (self.EXTRA_ROW_HEIGHT if self.expanded else 0))
        self.window.geometry(f"{width}x{height}")
        if self.expanded:
            self.update_lock_states()
        else:
            self.stop_lock_updates()
        self.layout()

    def stop_lock_updates(self):
        if self.lock_timer is not None:
            self.window.after_cancel(self.lock_timer)
            self.lock_timer = None

    def update_lock_states(self):
        self.lock_timer = None
        states = LockKeyState.read()
        if states != self.lock_states:
            self.lock_states = states
            self.refresh()
        if self.expanded and not self.closing:
            self.lock_timer = self.window.after(self.LOCK_STATE_INTERVAL, self.update_lock_states)

    def refresh(self):
        for name, button in (self.buttons | self.extended_buttons | self.numpad_buttons).items():
            active = name in self.held or name == self.pressed
            locked = name in self.locked
            if name == "language":
                button.configure(background=self.DARK_KEY_PRESSED_BACKGROUND if active else key_color(name),
                                 foreground="#202124" if active else "white")
            elif name in LockKeyState.KEYS:
                enabled = self.lock_states[name]
                button.configure(background=self.DARK_KEY_PRESSED_BACKGROUND if active else
                                 self.LOCK_ON_BACKGROUND if enabled else key_color(name),
                                 foreground="white" if enabled and not active else "#202124")
            else:
                button.configure(background=self.LOCKED_BACKGROUND if locked else "#34657c" if active else key_color(name),
                                 foreground=self.LOCKED_TEXT if locked else "white" if active else "#202124")
        for name, label, *_ in NUMPAD_KEYS:
            if name in NUMPAD_NAVIGATION and not self.lock_states["NumLock"]:
                label = NUMPAD_NAVIGATION[name][1]
            self.numpad_buttons[name].configure(text=label)
        layer = 1 + bool(self.held & {"LShift", "RShift"}) + 2 * bool(self.held & {"LAlt", "RAlt"})
        mode = f"Layer {layer}" if "Layer" in self.held else "普通输入"
        self.status.configure(text=mode)

    def layout(self, event=None):
        if event is not None and event.widget is not self.window:
            return
        width, height = self.window.winfo_width(), self.window.winfo_height()
        margin, gap, header = self.MARGIN, self.GAP, 25
        extra = self.EXTRA_ROW_HEIGHT if self.expanded else 0
        unit = (width - margin * 2 + gap) / (ROW_UNITS + self.NUMPAD_COLUMNS if self.expanded else ROW_UNITS)
        row_height = (height - header - margin - extra) / 6
        toolbar_width = len(self.toolbar) * 37
        self.status.place(x=margin, y=2, width=max(0, width - toolbar_width - margin * 2), height=20)
        for index, button in enumerate(self.toolbar):
            button.place(x=width - margin - toolbar_width + index * 37, y=2, width=35, height=20)
        for row_index, row in enumerate(ROWS):
            x = margin
            for name, label, units in row:
                self.buttons[name].place(x=round(x), y=round(header + row_index * row_height),
                                         width=round(units * unit - gap), height=max(12, round(row_height - gap)))
                self.buttons[name].configure(font=(self.UI_FONT if name == "language" else self.KEY_FONT,
                                                   8 if unit * ROW_UNITS < 600 else 9))
                x += units * unit
        for index, (name, _) in enumerate(EXTENDED_KEYS):
            button = self.extended_buttons[name]
            if self.expanded:
                button.place(x=margin + index * (width - margin * 2 + gap) / len(EXTENDED_KEYS),
                             y=height - extra,
                             width=(width - margin * 2 + gap) / len(EXTENDED_KEYS) - gap, height=extra - gap - margin)
                button.configure(font=(self.KEY_FONT, 8))
            else:
                button.place_forget()
        numpad_row = (height - header - margin - extra) / self.NUMPAD_ROWS
        for name, _, column, row, columns, rows in NUMPAD_KEYS:
            button = self.numpad_buttons[name]
            if self.expanded:
                button.place(x=round(margin + (ROW_UNITS + column) * unit),
                             y=round(header + row * numpad_row),
                             width=round(columns * unit - gap), height=round(rows * numpad_row - gap))
                button.configure(font=(self.KEY_FONT, 8))
            else:
                button.place_forget()

    def close(self):
        self.closing = True
        self.stop_lock_updates()
        try:
            self.reset()
        except RuntimeError:
            # 主程序退出时已收尾输入，窗口只需完成本地清理。
            pass
        finally:
            self.native.close()
            self.window.destroy()

    def run(self) -> None:
        self.window.mainloop()
