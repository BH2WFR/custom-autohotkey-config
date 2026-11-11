"""Windows 窗口单实例：互斥量决定所有者，就绪事件发布窗口句柄。"""

from contextlib import ExitStack
import ctypes as C
from ctypes import wintypes as W
import mmap
import struct

K = C.WinDLL("kernel32", use_last_error=True)
U = C.WinDLL("user32", use_last_error=True)
K.CreateMutexW.argtypes = [C.c_void_p, W.BOOL, W.LPCWSTR]
K.CreateMutexW.restype = W.HANDLE
K.CreateEventW.argtypes = [C.c_void_p, W.BOOL, W.BOOL, W.LPCWSTR]
K.CreateEventW.restype = W.HANDLE
K.WaitForMultipleObjects.argtypes = [W.DWORD, C.POINTER(W.HANDLE), W.BOOL, W.DWORD]
K.WaitForMultipleObjects.restype = W.DWORD
for name in ("CloseHandle", "ReleaseMutex", "SetEvent", "ResetEvent"):
    getattr(K, name).argtypes = [W.HANDLE]
    getattr(K, name).restype = W.BOOL
U.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.PostMessageW.restype = W.BOOL


class WindowInstance:
    HANDLE_FORMAT = "<Q"
    HANDLE_SIZE = struct.calcsize(HANDLE_FORMAT)
    STARTUP_TIMEOUT = 10000
    WAIT_OBJECT = 0
    WAIT_ABANDONED = 0x80
    WAIT_TIMEOUT = 0x102

    def __init__(self, name: str):
        self.name = name
        self.resources = ExitStack()
        self.owner = False

    def __enter__(self):
        try:
            self.mutex = self._handle(K.CreateMutexW(None, False, self.name + ".mutex"))
            self.ready = self._handle(K.CreateEventW(None, True, False, self.name + ".ready"))
            self.shared = self.resources.enter_context(
                mmap.mmap(-1, self.HANDLE_SIZE, tagname=self.name + ".window"))
            return self
        except BaseException:
            self.resources.close()
            raise

    def _handle(self, handle):
        if not handle:
            raise C.WinError(C.get_last_error())
        self.resources.callback(K.CloseHandle, handle)
        return handle

    def acquire_or_show(self, message: int) -> bool:
        handles = (W.HANDLE * 2)(self.mutex, self.ready)
        result = K.WaitForMultipleObjects(2, handles, False, self.STARTUP_TIMEOUT)
        if result in (self.WAIT_OBJECT, self.WAIT_ABANDONED):
            self.owner = True
            K.ResetEvent(self.ready)
            self.shared[:] = bytes(self.HANDLE_SIZE)
            return True
        if result == self.WAIT_OBJECT + 1:
            hwnd, = struct.unpack(self.HANDLE_FORMAT, self.shared[:])
            if not U.PostMessageW(hwnd, message, 0, 0):
                raise C.WinError(C.get_last_error())
            return False
        if result == self.WAIT_TIMEOUT:
            raise TimeoutError("等待已有窗口启动超时。")
        raise C.WinError(C.get_last_error())

    def publish(self, hwnd: int) -> None:
        self.shared[:] = struct.pack(self.HANDLE_FORMAT, hwnd)
        if not K.SetEvent(self.ready):
            raise C.WinError(C.get_last_error())

    def __exit__(self, *exc):
        if self.owner:
            K.ReleaseMutex(self.mutex)
        self.resources.close()
