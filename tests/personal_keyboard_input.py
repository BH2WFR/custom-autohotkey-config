"""Exercise the external keyboard's real Win32 output against an isolated AHK window."""

import sys
import time
from pathlib import Path


def main():
    entry = Path(sys.argv[1])
    target = int(sys.argv[2])
    sys.path[:0] = [str(entry.parent), str(entry.parents[2])]
    from screen_keyboard.windows import WindowsOutput
    from screen_keyboard.state import LeftKeyMode

    output = WindowsOutput()
    try:
        for mode, modifiers in ((LeftKeyMode.F24, []), (LeftKeyMode.F1, ["LShift"]),
                                (LeftKeyMode.CAPS, ["LAlt"]), (LeftKeyMode.F24, ["LShift", "LAlt"])):
            if output.target() != target:
                raise RuntimeError("Input target lost focus")
            output.mode = mode
            output.hold("Layer", True)
            for key in modifiers:
                output.hold(key, True)
            for _ in range(2):
                time.sleep(0.1)
                output.key("2", modifiers)
            time.sleep(0.1)
            output.reset()
            time.sleep(0.1)
        # Release the onscreen modifiers while the final AHK action is still running.
        if output.target() != target:
            raise RuntimeError("Input target lost focus")
        output.hold("LShift", True)
        output.hold("LAlt", True)
        output.hold("Layer", True)
        time.sleep(0.1)
        output.key("2", ["LShift", "LAlt"])
        time.sleep(0.08)
    finally:
        output.reset()


if __name__ == "__main__":
    main()
