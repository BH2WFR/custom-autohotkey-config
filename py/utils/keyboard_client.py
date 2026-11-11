"""AHK 屏幕输入通道；Python 不自行注入按键。"""
import ctypes as C
from ctypes import wintypes as W
import json

USER32 = C.WinDLL("user32", use_last_error=True)
WM_COPYDATA = 0x004A
PROTOCOL = 0x534B01
SMTO_ABORTIFHUNG = 0x0002


class CopyData(C.Structure):
    _fields_ = [("tag", C.c_size_t), ("size", W.DWORD), ("data", C.c_void_p)]


USER32.SendMessageTimeoutW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM,
                                      W.UINT, W.UINT, C.POINTER(C.c_size_t)]
USER32.SendMessageTimeoutW.restype = W.LPARAM


class KeyboardClient:
    def __init__(self, host: int, hwnd: int) -> None:
        self.host = host
        self.hwnd = hwnd

    def send(self, command: str, modifiers=(), key: str = "") -> None:
        text = json.dumps({"command": command, "modifiers": list(modifiers), "key": key})
        payload = C.create_unicode_buffer(text)
        packet = CopyData(PROTOCOL, C.sizeof(payload), C.addressof(payload))
        result = C.c_size_t()
        ok = USER32.SendMessageTimeoutW(self.host, WM_COPYDATA, self.hwnd,
                                       C.addressof(packet), SMTO_ABORTIFHUNG, 1000,
                                       C.byref(result))
        if not ok or not result.value:
            raise RuntimeError("屏幕键盘未能连接 AHK 主程序。")
