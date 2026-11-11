"""不抢占焦点的 Windows 屏幕键盘。"""

from pathlib import Path
import tkinter as tk
from tkinter import messagebox

from utils.keyboard_client import KeyboardClient
from utils.keyboard_state import LockKeyState
from utils.nonactivating_window import NonactivatingWindow


ROW_UNITS = 16
DEFAULT_SIZE = (512, 197)
MINIMUM_SIZE = (426, 166)
MODIFIERS = {"LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"}
STICKY_KEYS = MODIFIERS | {"Layer"}
ACCENT_LOCK_KEYS = {"NumLock", "ScrollLock"}
ROWS = [
    [("Esc", "Esc", 1)] + [(f"F{i}", f"F{i}", 1) for i in range(1, 13)]
    + [("language", "语言", 1), ("Insert", "Ins", 1), ("Delete", "Del", 1)],
    [(c, label, 1) for c, label in zip("`1234567890-=",
     ["` ~", "1 !", "2 @", "3 #", "4 $", "5 %", "6 ^", "7 &", "8 *", "9 (", "0 )", "- _", "= +"])]
    + [("Backspace", "⌫", 2), ("Home", "Home", 1)],
    [("Tab", "Tab", 1.5)] + [(c, c.upper(), 1) for c in "qwertyuiop"]
    + [("[", "[ {", 1), ("]", "] }", 1), ("\\", "\\ |", 1.5), ("End", "End", 1)],
    [("Layer", "Layer", 2)] + [(c, c.upper(), 1) for c in "asdfghjkl"]
    + [(";", "; :", 1), ("'", "' \"", 1), ("Enter", "Enter", 2), ("PgUp", "PgUp", 1)],
    [("LShift", "Shift", 1.5), ("vkE2sc056", "\\ |", 1)]
    + [(c, c.upper(), 1) for c in "zxcvbnm"]
    + [(",", ", <", 1), (".", ". >", 1), ("/", "/ ?", 1), ("RShift", "Shift", 1.5),
       ("Up", "↑", 1), ("PgDn", "PgDn", 1)],
    [("LControl", "Ctrl", 1.25), ("LWin", "Win", 1.25), ("LAlt", "Alt", 1.25),
     ("Space", "Space", 5.5), ("RAlt", "Alt", 1.25), ("AppsKey", "Menu", 1.25),
     ("RControl", "Ctrl", 1.25), ("Left", "←", 1), ("Down", "↓", 1), ("Right", "→", 1)],
]
EXTENDED_KEYS = [("PrintScreen", "PrtSc"), ("ScrollLock", "ScrLk"), ("Pause", "Pause"),
                 ("CapsLock", "Caps"), ("RWin", "RWin"),
                 *[(f"F{i}", f"F{i}") for i in range(13, 25)]]
# 名称、标签、列、行、列跨度、行跨度。
NUMPAD_KEYS = [
    ("NumLock", "Num", 0, 0, 1, 1), ("NumpadDiv", "/", 1, 0, 1, 1),
    ("NumpadMult", "*", 2, 0, 1, 1), ("NumpadSub", "−", 3, 0, 1, 1),
    ("Numpad7", "7", 0, 1, 1, 1), ("Numpad8", "8", 1, 1, 1, 1),
    ("Numpad9", "9", 2, 1, 1, 1), ("NumpadAdd", "+", 3, 1, 1, 2),
    ("Numpad4", "4", 0, 2, 1, 1), ("Numpad5", "5", 1, 2, 1, 1),
    ("Numpad6", "6", 2, 2, 1, 1), ("Numpad1", "1", 0, 3, 1, 1),
    ("Numpad2", "2", 1, 3, 1, 1), ("Numpad3", "3", 2, 3, 1, 1),
    ("NumpadEnter", "Enter", 3, 3, 1, 2), ("Numpad0", "0", 0, 4, 2, 1),
    ("NumpadDot", ".", 2, 4, 1, 1),
]
NUMPAD_NAVIGATION = {
    "Numpad0": ("NumpadIns", "Ins"), "Numpad1": ("NumpadEnd", "End"),
    "Numpad2": ("NumpadDown", "↓"), "Numpad3": ("NumpadPgDn", "PgDn"),
    "Numpad4": ("NumpadLeft", "←"), "Numpad5": ("NumpadClear", "Clear"),
    "Numpad6": ("NumpadRight", "→"), "Numpad7": ("NumpadHome", "Home"),
    "Numpad8": ("NumpadUp", "↑"), "Numpad9": ("NumpadPgUp", "PgUp"),
    "NumpadDot": ("NumpadDel", "Del"),
}
PALETTE = {"letters": "#aadef6", "symbols": "#ffdc68", "modifiers": "#59c1e7",
           "layer": "#f78bb5", "arrows": "#eba7f4", "navigation": "#99db9d",
           "commands": "#64cd7c", "language": "#438a62", "locks": "#e8a07d"}


def key_color(name: str) -> str:
    if name == "Layer":
        group = "layer"
    elif name in ACCENT_LOCK_KEYS:
        group = "locks"
    elif name in MODIFIERS:
        group = "modifiers"
    elif name in {"Left", "Right", "Up", "Down"}:
        group = "arrows"
    elif name == "language":
        group = "language"
    elif len(name) == 1 and name.isalpha():
        group = "letters"
    elif name in {"Esc", "Tab", "Enter", "NumpadEnter", "Backspace", "Delete", "Insert", "AppsKey"}:
        group = "commands"
    elif len(name) == 1 or name in {"Space", "vkE2sc056"} or name.startswith("Numpad"):
        group = "symbols"
    else:
        group = "navigation"
    return PALETTE[group]


class ScreenKeyboard:
    LOCK_DELAY = 500
    REPEAT_DELAY = 450
    REPEAT_INTERVAL = 45
    BACKGROUND = "#f1f3f5"
    LOCKED_BACKGROUND = "#7a202a"
    LOCKED_TEXT = "#ffe160"
    DARK_KEY_PRESSED_BACKGROUND = "#99db9d"
    LANGUAGE_PRESSED_BACKGROUND = "#185337"
    UI_FONT = "Microsoft YaHei UI"
    KEY_FONT = "Segoe UI"
    LOCK_STATE_INTERVAL = 250
    LOCK_ON_BACKGROUND = "#185337"
    ACCENT_LOCK_ON_BACKGROUND = "#9f4929"
    ACCENT_LOCK_PRESSED_BACKGROUND = "#f4bd9d"
    EXTRA_ROW_HEIGHT = 30
    NUMPAD_COLUMNS = 4
    NUMPAD_ROWS = 5
    MARGIN = 4
    GAP = 3
    BORDER_COLOR = "#c1c9ce"
    BORDER_WIDTH = 1
    HOVER_BLEND = 0.35
    DARK_HOVER_BLEND = 0.18
    DARK_THRESHOLD = 128
    TOGGLE_BACKGROUND = "#34657c"

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
        self.numpad_visible = False
        self.closing = False
        self.lock_states = LockKeyState.read()
        self.lock_timer = None
        self.buttons = {}
        self.extended_buttons = {}
        self.numpad_buttons = {}
        self.hovered = set()
        self.button_colors = {}
        self.status = tk.Label(self.window, anchor="w", background=self.BACKGROUND,
                               foreground="#505760", font=(self.UI_FONT, 8))
        self.toolbar = []
        self.toolbar_buttons = {}
        for name, label, action in [("extended", "更多", self.toggle_extended),
                                    ("numpad", "数字", self.toggle_numpad),
                                    ("reset", "释放", self.reset),
                                    ("size", "复位", self.reset_size)]:
            button = tk.Label(self.window, text=label, background=self.BACKGROUND,
                               font=(self.UI_FONT, 8), cursor="hand2")
            button.bind("<ButtonRelease-1>", lambda event, fn=action: self.perform(fn))
            if name in {"extended", "numpad"}:
                button.configure(borderwidth=0, highlightthickness=self.BORDER_WIDTH,
                                 highlightbackground=self.BORDER_COLOR, highlightcolor=self.BORDER_COLOR)
            self.bind_hover(button)
            self.paint_button(button, self.BACKGROUND, "#202124")
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
                           borderwidth=0, relief="flat", highlightthickness=self.BORDER_WIDTH,
                           highlightbackground=self.BORDER_COLOR, highlightcolor=self.BORDER_COLOR,
                           font=(self.UI_FONT if name == "language" else self.KEY_FONT, 9), cursor="arrow")
        button.bind("<ButtonPress-1>", lambda event: self.perform(lambda: self.press(name)))
        self.bind_hover(button)
        self.paint_button(button, key_color(name), "white" if name == "language" else "#202124")
        return button

    def bind_hover(self, button):
        button.bind("<Enter>", lambda event: self.set_hover(button, True))
        button.bind("<Leave>", lambda event: self.set_hover(button, False))
        button.bind("<Unmap>", lambda event: self.set_hover(button, False))

    @classmethod
    def hover_color(cls, color):
        rgb = [int(color[index:index + 2], 16) for index in (1, 3, 5)]
        blend = cls.DARK_HOVER_BLEND if max(rgb) < cls.DARK_THRESHOLD else cls.HOVER_BLEND
        return "#" + "".join(f"{round(channel + (255 - channel) * blend):02x}" for channel in rgb)

    def set_hover(self, button, hovered):
        if hovered:
            self.hovered.add(button)
        else:
            self.hovered.discard(button)
        color = self.button_colors[button]
        button.configure(background=self.hover_color(color) if hovered else color)

    def paint_button(self, button, background, foreground):
        self.button_colors[button] = background
        button.configure(background=self.hover_color(background) if button in self.hovered else background,
                         foreground=foreground)

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
        self.numpad_visible = False
        self.resize_panels(*DEFAULT_SIZE)

    def toggle_extended(self):
        self.window.update_idletasks()
        self.expanded = not self.expanded
        height = self.window.winfo_height() + (self.EXTRA_ROW_HEIGHT if self.expanded else -self.EXTRA_ROW_HEIGHT)
        self.resize_panels(self.window.winfo_width(), height)

    def toggle_numpad(self):
        self.window.update_idletasks()
        self.numpad_visible = not self.numpad_visible
        ratio = (ROW_UNITS + self.NUMPAD_COLUMNS) / ROW_UNITS
        width = self.window.winfo_width() - self.MARGIN * 2 + self.GAP
        width = round(width * ratio if self.numpad_visible else width / ratio) + self.MARGIN * 2 - self.GAP
        self.resize_panels(width, self.window.winfo_height())

    def resize_panels(self, width, height):
        ratio = (ROW_UNITS + self.NUMPAD_COLUMNS) / ROW_UNITS
        self.window.minsize(round(MINIMUM_SIZE[0] * ratio) if self.numpad_visible else MINIMUM_SIZE[0],
                            MINIMUM_SIZE[1] + (self.EXTRA_ROW_HEIGHT if self.expanded else 0))
        self.window.geometry(f"{width}x{height}")
        self.window.update_idletasks()
        self.stop_lock_updates()
        if self.expanded or self.numpad_visible:
            self.update_lock_states()
        self.refresh()
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
        if (self.expanded or self.numpad_visible) and not self.closing:
            self.lock_timer = self.window.after(self.LOCK_STATE_INTERVAL, self.update_lock_states)

    def refresh(self):
        for name, enabled in [("extended", self.expanded), ("numpad", self.numpad_visible)]:
            self.paint_button(self.toolbar_buttons[name], self.TOGGLE_BACKGROUND if enabled else self.BACKGROUND,
                              "white" if enabled else "#202124")
        for name, button in (self.buttons | self.extended_buttons | self.numpad_buttons).items():
            active = name in self.held or name == self.pressed
            locked = name in self.locked
            if name == "language":
                self.paint_button(button, self.LANGUAGE_PRESSED_BACKGROUND if active else key_color(name), "white")
            elif name in LockKeyState.KEYS:
                enabled = self.lock_states[name]
                on_color = self.ACCENT_LOCK_ON_BACKGROUND if name in ACCENT_LOCK_KEYS else self.LOCK_ON_BACKGROUND
                pressed_color = self.ACCENT_LOCK_PRESSED_BACKGROUND if name in ACCENT_LOCK_KEYS else self.DARK_KEY_PRESSED_BACKGROUND
                self.paint_button(button, pressed_color if active else on_color if enabled else key_color(name),
                                  "white" if enabled and not active else "#202124")
            else:
                self.paint_button(button, self.LOCKED_BACKGROUND if locked else "#34657c" if active else key_color(name),
                                  self.LOCKED_TEXT if locked else "white" if active else "#202124")
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
        unit = (width - margin * 2 + gap) / (ROW_UNITS + self.NUMPAD_COLUMNS if self.numpad_visible else ROW_UNITS)
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
            if self.numpad_visible:
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
