"""不抢占焦点的 Windows 屏幕键盘。"""

from pathlib import Path
import tkinter as tk
from tkinter import messagebox

from gui.keyboard_layout import (DEFAULT_SIZE, EXTENDED_KEYS, MINIMUM_SIZE, MODIFIERS,
                                 ROWS, ROW_UNITS, STICKY_KEYS, key_color)
from utils.keyboard_client import KeyboardClient
from utils.nonactivating_window import NonactivatingWindow


class ScreenKeyboard:
    LOCK_DELAY = 500
    REPEAT_DELAY = 450
    REPEAT_INTERVAL = 45
    BACKGROUND = "#f1f3f5"
    LOCKED_BACKGROUND = "#7a202a"
    LOCKED_TEXT = "#ffe160"

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
        self.buttons = {}
        self.extended_buttons = {}
        self.status = tk.Label(self.window, anchor="w", background=self.BACKGROUND,
                               foreground="#505760", font=("Segoe UI", 8))
        self.toolbar = []
        for label, action in [("语言", self.language), ("释放", self.reset),
                              ("复位", self.reset_size), ("—", self.minimize)]:
            button = tk.Label(self.window, text=label, background=self.BACKGROUND,
                               font=("Microsoft YaHei UI", 8), cursor="hand2")
            button.bind("<ButtonRelease-1>", lambda event, fn=action: self.perform(fn))
            self.toolbar.append(button)
        for row in ROWS:
            for name, label, units in row:
                self.buttons[name] = self.make_button(name, label)
        for name, label in EXTENDED_KEYS:
            self.extended_buttons[name] = self.make_button(name, label)
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
                           foreground="white" if name == "extended" else "#202124",
                           borderwidth=1, relief="solid", font=("Segoe UI", 9), cursor="arrow")
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
        self.client.send(command, sorted(self.held & MODIFIERS), key)

    def press(self, name):
        self.check_target()
        self.cancel_timer()
        self.pressed = name
        if name == "extended":
            self.expanded = not self.expanded
            width = self.window.winfo_width()
            height = self.window.winfo_height() + (64 if self.expanded else -64)
            self.window.geometry(f"{width}x{height}")
            self.layout()
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
        if name and name not in STICKY_KEYS and name != "extended":
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

    def minimize(self):
        self.reset()
        self.native.minimize()

    def reset_size(self):
        self.expanded = False
        self.window.geometry("%dx%d" % DEFAULT_SIZE)

    def refresh(self):
        for name, button in list(self.buttons.items()) + list(self.extended_buttons.items()):
            active = name in self.held or name == self.pressed
            locked = name in self.locked
            button.configure(background=self.LOCKED_BACKGROUND if locked else "#34657c" if active else key_color(name),
                             foreground=self.LOCKED_TEXT if locked else "white" if active or name == "extended" else "#202124")
        layer = 1 + bool(self.held & {"LShift", "RShift"}) + 2 * bool(self.held & {"LAlt", "RAlt"})
        mode = f"Layer {layer}" if "Layer" in self.held else "普通输入"
        self.status.configure(text=mode)

    def layout(self, event=None):
        if event is not None and event.widget is not self.window:
            return
        width, height = self.window.winfo_width(), self.window.winfo_height()
        margin, gap, header = 4, 3, 25
        extra = 64 if self.expanded else 0
        unit = (width - margin * 2 + gap) / ROW_UNITS
        row_height = (height - header - margin - extra) / 6
        self.status.place(x=margin, y=2, width=max(0, width - 160), height=20)
        for index, button in enumerate(self.toolbar):
            button.place(x=width - 152 + index * 37, y=2, width=35, height=20)
        for row_index, row in enumerate(ROWS):
            x = margin
            for name, label, units in row:
                self.buttons[name].place(x=round(x), y=round(header + row_index * row_height),
                                         width=round(units * unit - gap), height=max(12, round(row_height - gap)))
                self.buttons[name].configure(font=("Segoe UI", 8 if width < 600 else 9))
                x += units * unit
        for index, (name, _) in enumerate(EXTENDED_KEYS):
            button = self.extended_buttons[name]
            if self.expanded:
                button.place(x=margin + index % 9 * (width - margin * 2) / 9,
                             y=height - extra + index // 9 * 30,
                             width=(width - margin * 2) / 9 - gap, height=27)
            else:
                button.place_forget()

    def close(self):
        self.closing = True
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
