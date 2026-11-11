"""Python GUI 功能入口。"""

import argparse

from gui.screen_keyboard import ScreenKeyboard
from utils.nonactivating_window import WM_SHOW_KEYBOARD
from utils.single_instance import WindowInstance


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["screen-keyboard"])
    parser.add_argument("--host", type=int, required=True)
    args = parser.parse_args()
    # 屏幕输入归 AHK 宿主管理，重载后的新会话不复用旧宿主的输入通道。
    name = rf"Local\custom-autohotkey-config.screen-keyboard.{args.host}"
    with WindowInstance(name) as instance:
        if not instance.acquire_or_show(WM_SHOW_KEYBOARD):
            return
        keyboard = ScreenKeyboard(args.host)
        instance.publish(keyboard.native.hwnd)
        keyboard.run()


if __name__ == "__main__":
    main()
