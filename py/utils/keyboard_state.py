"""读取 Windows 锁定键状态，不发送输入。"""
import ctypes as C

USER32 = C.WinDLL("user32")
USER32.GetKeyState.argtypes = [C.c_int]
USER32.GetKeyState.restype = C.c_short


class LockKeyState:
    KEYS = {"NumLock": 0x90, "ScrollLock": 0x91, "CapsLock": 0x14}

    @classmethod
    def read(cls):
        return {name: bool(USER32.GetKeyState(code) & 1) for name, code in cls.KEYS.items()}
