"""Python GUI 功能入口。"""

import argparse

from gui.screen_keyboard import ScreenKeyboard


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["screen-keyboard"])
    parser.parse_args()
    ScreenKeyboard().run()


if __name__ == "__main__":
    main()
