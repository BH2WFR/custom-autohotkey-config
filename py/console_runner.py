"""Enable ANSI output in a fresh Windows console before running a Python tool."""

import ctypes
from ctypes import wintypes
import msvcrt
import os
import runpy
import sys


def enable_ansi(stream):
    handle = wintypes.HANDLE(msvcrt.get_osfhandle(stream.fileno()))
    mode = wintypes.DWORD()
    kernel = ctypes.windll.kernel32
    if kernel.GetConsoleMode(handle, ctypes.byref(mode)):
        # ENABLE_PROCESSED_OUTPUT and ENABLE_VIRTUAL_TERMINAL_PROCESSING.
        if not kernel.SetConsoleMode(handle, mode.value | 0x0001 | 0x0004):
            raise ctypes.WinError()


if __name__ == "__main__":
    enable_ansi(sys.stdout)
    enable_ansi(sys.stderr)
    sys.argv = sys.argv[1:]
    script = os.path.abspath(sys.argv[0])
    sys.path[0] = os.path.dirname(script)
    runpy.run_path(script, run_name="__main__")
