"""沿用 macOS RDP 键盘的六行、16 单位布局及配色。"""
ROW_UNITS = 16
DEFAULT_SIZE = (512, 197)
MINIMUM_SIZE = (426, 166)
MODIFIERS = {"LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"}
STICKY_KEYS = MODIFIERS | {"Layer"}
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
           "commands": "#64cd7c", "language": "#185337"}


def key_color(name: str) -> str:
    if name == "Layer":
        group = "layer"
    elif name in MODIFIERS:
        group = "modifiers"
    elif name in {"Left", "Right", "Up", "Down"}:
        group = "arrows"
    elif name == "language":
        group = "language"
    elif len(name) == 1 and name.isalpha():
        group = "letters"
    elif len(name) == 1 or name in {"Space", "vkE2sc056"} or name.startswith("Numpad"):
        group = "symbols"
    elif name in {"Esc", "Tab", "Enter", "Backspace", "Delete", "Insert", "AppsKey"}:
        group = "commands"
    else:
        group = "navigation"
    return PALETTE[group]
