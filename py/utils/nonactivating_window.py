"""Tk 浮动窗口的 Windows 非激活显示及定位。"""
import ctypes as C
from ctypes import wintypes as W
from queue import SimpleQueue
from threading import Thread

U = C.WinDLL("user32", use_last_error=True)
LONG_PTR = C.c_ssize_t
WNDPROC = C.WINFUNCTYPE(LONG_PTR, W.HWND, W.UINT, W.WPARAM, W.LPARAM)
GWLP_WNDPROC = -4
GWL_EXSTYLE = -20
GWL_STYLE = -16
WS_MINIMIZEBOX = 0x00020000
WS_EX_NOACTIVATE = 0x08000000
WS_EX_TOOLWINDOW = 0x00000080
WM_MOUSEACTIVATE = 0x0021
WM_RESET_KEYBOARD = 0x8001
WM_SHOW_KEYBOARD = 0x8002
MA_NOACTIVATE = 3
GA_ROOT = 2
SW_SHOWNOACTIVATE = 4
SWP_NOSIZE = 0x0001
SWP_NOMOVE = 0x0002
SWP_NOACTIVATE = 0x0010
SWP_FRAMECHANGED = 0x0020
HWND_TOP = 0
HWND_TOPMOST = -1
MONITOR_DEFAULTTONEAREST = 2
PER_MONITOR_AWARE_V2 = -4
CURSOR_GAP = 12


class MonitorInfo(C.Structure):
    _fields_ = [("size", W.DWORD), ("monitor", W.RECT),
                ("work", W.RECT), ("flags", W.DWORD)]

U.GetAncestor.argtypes = [W.HWND, W.UINT]
U.GetAncestor.restype = W.HWND
U.GetForegroundWindow.restype = W.HWND
U.GetWindowLongPtrW.argtypes = [W.HWND, C.c_int]
U.GetWindowLongPtrW.restype = LONG_PTR
U.SetWindowLongPtrW.argtypes = [W.HWND, C.c_int, LONG_PTR]
U.SetWindowLongPtrW.restype = LONG_PTR
U.CallWindowProcW.argtypes = [LONG_PTR, W.HWND, W.UINT, W.WPARAM, W.LPARAM]
U.CallWindowProcW.restype = LONG_PTR
U.ShowWindow.argtypes = [W.HWND, C.c_int]
U.SetWindowPos.argtypes = [W.HWND, W.HWND, C.c_int, C.c_int, C.c_int, C.c_int, W.UINT]
U.GetCursorPos.argtypes = [C.POINTER(W.POINT)]
U.GetWindowRect.argtypes = [W.HWND, C.POINTER(W.RECT)]
U.MonitorFromPoint.argtypes = [W.POINT, W.DWORD]
U.MonitorFromPoint.restype = W.HANDLE
U.GetMonitorInfoW.argtypes = [W.HANDLE, C.POINTER(MonitorInfo)]
U.SetThreadDpiAwarenessContext.argtypes = [W.HANDLE]
U.SetThreadDpiAwarenessContext.restype = W.HANDLE


class NonactivatingWindow:
    @staticmethod
    def foreground():
        return U.GetForegroundWindow()

    def __init__(self, root, on_reset) -> None:
        self.root = root
        self.on_reset = on_reset
        self.commands = SimpleQueue()
        self.closed = False
        # Tk 首次映射会主动 SetActiveWindow；先在禁用状态完成映射。
        root.attributes("-disabled", True)
        root.deiconify()
        root.update_idletasks()
        root.withdraw()
        root.attributes("-disabled", False)
        self.hwnd = U.GetAncestor(root.winfo_id(), GA_ROOT)
        style = U.GetWindowLongPtrW(self.hwnd, GWL_STYLE)
        U.SetWindowLongPtrW(self.hwnd, GWL_STYLE, style & ~WS_MINIMIZEBOX)
        style = U.GetWindowLongPtrW(self.hwnd, GWL_EXSTYLE)
        U.SetWindowLongPtrW(self.hwnd, GWL_EXSTYLE,
                           style | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW)
        self.proc = WNDPROC(self._window_proc)
        self.old_proc = U.SetWindowLongPtrW(self.hwnd, GWLP_WNDPROC,
                                           C.cast(self.proc, C.c_void_p).value)
        root.after(0, self._start_dispatcher)

    def _start_dispatcher(self):
        Thread(target=self._dispatch, daemon=True).start()

    def _dispatch(self):
        # ctypes 窗口回调中直接调用 Tk 会破坏 Tcl 的线程状态；经 Tk 的跨线程队列调度。
        # 工作线程阻塞等待消息，空闲时不轮询。
        while (command := self.commands.get()) is not None:
            if self.closed:
                return
            try:
                self.root.after(0, command)
            except RuntimeError:
                if self.closed:
                    return
                raise

    def _window_proc(self, hwnd, message, wp, lp):
        if message == WM_MOUSEACTIVATE:
            return MA_NOACTIVATE
        if message == WM_RESET_KEYBOARD:
            self.commands.put(self.on_reset)
            return 0
        if message == WM_SHOW_KEYBOARD:
            self.commands.put(self.show)
            return 0
        return U.CallWindowProcW(self.old_proc, hwnd, message, wp, lp)

    def show(self) -> None:
        self.root.update_idletasks()
        U.ShowWindow(self.hwnd, SW_SHOWNOACTIVATE)
        self.place_near_cursor()
        # 显示和定位后再提升 Z 序，盖过已存在的置顶窗口，保留输入目标焦点。
        U.SetWindowPos(self.hwnd, W.HWND(HWND_TOP), 0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED)

    def place_near_cursor(self) -> None:
        # 在同一 DPI 上下文中读取鼠标、外框及工作区，兼容副屏负坐标和混合缩放。
        previous = U.SetThreadDpiAwarenessContext(W.HANDLE(PER_MONITOR_AWARE_V2))
        try:
            point, rect = W.POINT(), W.RECT()
            U.GetCursorPos(C.byref(point))
            U.GetWindowRect(self.hwnd, C.byref(rect))
            monitor = U.MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST)
            info = MonitorInfo(size=C.sizeof(MonitorInfo))
            if not U.GetMonitorInfoW(monitor, C.byref(info)):
                raise C.WinError(C.get_last_error())
            work = info.work
            width = min(rect.right - rect.left, work.right - work.left)
            height = min(rect.bottom - rect.top, work.bottom - work.top)
            x, y = point.x + CURSOR_GAP, point.y + CURSOR_GAP
            if x + width > work.right:
                x = point.x - width - CURSOR_GAP
            if y + height > work.bottom:
                y = point.y - height - CURSOR_GAP
            x = max(work.left, min(x, work.right - width))
            y = max(work.top, min(y, work.bottom - height))
            U.SetWindowPos(self.hwnd, W.HWND(HWND_TOPMOST), x, y, width, height, SWP_NOACTIVATE)
        finally:
            U.SetThreadDpiAwarenessContext(previous)

    def close(self) -> None:
        self.closed = True
        self.commands.put(None)
        U.SetWindowLongPtrW(self.hwnd, GWLP_WNDPROC, self.old_proc)
