"""屏幕键盘占位窗口。"""

from pathlib import Path
import tkinter as tk


class ScreenKeyboard:
    def __init__(self) -> None:
        self.window = tk.Tk()
        self.window.title("屏幕键盘 — Custom Autohotkey Config")
        self.window.geometry("900x300")
        self.window.minsize(450, 150)
        self.window.iconbitmap(str(Path(__file__).resolve().parents[2] / "res" / "MainIcon.ico"))

    def run(self) -> None:
        self.window.mainloop()
