"""Tk 窗口的 Per-Monitor V2 生命周期；原生回调只复制消息并入队。"""
import ctypes as C
from ctypes import wintypes as W
from functools import partial
from queue import SimpleQueue
from threading import Thread

U = C.WinDLL("user32", use_last_error=True)
LONG_PTR = C.c_ssize_t
WNDPROC = C.WINFUNCTYPE(LONG_PTR, W.HWND, W.UINT, W.WPARAM, W.LPARAM)
GWLP_WNDPROC = -4
GA_ROOT = 2
WM_DPICHANGED = 0x02E0
BASE_DPI = 96
PER_MONITOR_AWARE_V2 = -4
SWP_NOZORDER = 0x0004
SWP_NOACTIVATE = 0x0010
MONITOR_DEFAULTTONEAREST = 2


class MonitorInfo(C.Structure):
    _fields_ = [("size", W.DWORD), ("monitor", W.RECT), ("work", W.RECT), ("flags", W.DWORD)]

U.GetAncestor.argtypes = [W.HWND, W.UINT]
U.GetAncestor.restype = W.HWND
U.GetWindowLongPtrW.argtypes = [W.HWND, C.c_int]
U.GetWindowLongPtrW.restype = LONG_PTR
U.SetWindowLongPtrW.argtypes = [W.HWND, C.c_int, LONG_PTR]
U.SetWindowLongPtrW.restype = LONG_PTR
U.CallWindowProcW.argtypes = [LONG_PTR, W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.CallWindowProcW.restype = LONG_PTR
U.SetWindowPos.argtypes = [W.HWND, W.HWND, C.c_int, C.c_int, C.c_int, C.c_int, W.UINT]
U.GetDpiForWindow.argtypes = [W.HWND]
U.GetDpiForWindow.restype = W.UINT
U.GetDpiForSystem.restype = W.UINT
U.SetThreadDpiAwarenessContext.argtypes = [W.HANDLE]
U.SetThreadDpiAwarenessContext.restype = W.HANDLE
U.MonitorFromRect.argtypes = [C.POINTER(W.RECT), W.DWORD]
U.MonitorFromRect.restype = W.HANDLE
U.GetMonitorInfoW.argtypes = [W.HANDLE, C.POINTER(MonitorInfo)]


class DpiWindow:
    @staticmethod
    def enable():
        # 必须在 Tk() 创建窗口前调用；不更改其他进程或系统设置。
        if not U.SetThreadDpiAwarenessContext(W.HANDLE(PER_MONITOR_AWARE_V2)):
            raise C.WinError(C.get_last_error())

    @staticmethod
    def system_dpi():
        return U.GetDpiForSystem()

    def __init__(self, root, on_dpi):
        self.root = root
        self.on_dpi = on_dpi
        self.hwnd = U.GetAncestor(root.winfo_id(), GA_ROOT)
        self.dpi = U.GetDpiForWindow(self.hwnd)
        self.commands = SimpleQueue()
        self.closed = False
        self.proc = WNDPROC(self._window_proc)
        self.old_proc = U.SetWindowLongPtrW(self.hwnd, GWLP_WNDPROC, C.cast(self.proc, C.c_void_p).value)
        root.after(0, self._start_dispatcher)
        self.on_dpi(self.dpi)

    def _start_dispatcher(self):
        Thread(target=self._dispatch, daemon=True).start()

    def _dispatch(self):
        while (command := self.commands.get()) is not None:
            if self.closed:
                return
            try:
                self.root.after(0, self._run, command)
            except RuntimeError:
                if self.closed:
                    return
                raise

    def _run(self, command):
        if not self.closed:
            command()

    def _window_proc(self, hwnd, message, wp, lp):
        if message == WM_DPICHANGED:
            rect = C.cast(lp, C.POINTER(W.RECT)).contents
            bounds = (rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top)
            self.commands.put(partial(self.apply_dpi, wp & 0xFFFF, bounds))
            return 0
        return U.CallWindowProcW(self.old_proc, hwnd, message, wp, lp)

    def apply_dpi(self, dpi, bounds):
        self.dpi = dpi
        self.on_dpi(dpi)
        U.SetWindowPos(self.hwnd, None, *self.fit_bounds(bounds), SWP_NOZORDER | SWP_NOACTIVATE)
        self.root.update_idletasks()

    @staticmethod
    def fit_bounds(bounds):
        x, y, width, height = bounds
        rect = W.RECT(x, y, x + width, y + height)
        monitor = U.MonitorFromRect(C.byref(rect), MONITOR_DEFAULTTONEAREST)
        info = MonitorInfo(size=C.sizeof(MonitorInfo))
        if not U.GetMonitorInfoW(monitor, C.byref(info)):
            raise C.WinError(C.get_last_error())
        work = info.work
        width, height = min(width, work.right - work.left), min(height, work.bottom - work.top)
        return max(work.left, min(x, work.right - width)), max(work.top, min(y, work.bottom - height)), width, height

    def close(self):
        self.closed = True
        self.commands.put(None)
        U.SetWindowLongPtrW(self.hwnd, GWLP_WNDPROC, self.old_proc)
