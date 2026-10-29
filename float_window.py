# 课堂快捷悬浮球 —— 主程序的第二个窗口
#
# 设计要点：
# · **同进程**：和主窗口共用一个 QQmlApplicationEngine / RewardBridge / AppController，
#   所以数据天然同步，而"打开完整界面"只是 show + raise，不用重启进程（秒开）。
# · 窗口：无边框 + 置顶 + 不抢焦点（WS_EX_NOACTIVATE，PPT 放映时不打断键盘）；
#   ⚠️ 不能设 Qt.Tool —— 那会变成 WS_POPUP，任务栏是没了，但以后要加系统模糊就不生效。
# · 形状：窗口矩形比可见内容大（球态也要留出气泡的位置），靠 setMask 裁成
#   "球 / 球+气泡 / 整卡" 三种形状 —— 形状之外**点击穿透**，不挡下面的 PPT。
import ctypes
import os

from PySide6.QtCore import QObject, QUrl, Slot
from PySide6.QtGui import QRegion

# 与 FloatBall.qml 里保持一致的两组几何
BALL_OFF = (140, 150)
BALL_SIZE = 100
BUBBLE_OFFS = [(-74, 74), (-105, 0), (-74, -74), (0, -105)]
BUBBLE_SIZE = 68


def _circle(cx, cy, r):
    return QRegion(int(cx - r), int(cy - r), int(2 * r), int(2 * r), QRegion.Ellipse)


class _FloatBridge(QObject):
    """给悬浮球 QML 用的"回主程序"接口。"""

    def __init__(self, main_win, parent=None):
        super().__init__(parent)
        self._main = main_win
        self.win = None

    @Slot()
    def showMain(self):
        """气泡①「软件主界面」：把主窗口调出来（同进程，秒开）"""
        w = self._main
        if w is None:
            return
        w.show()
        w.raise_()
        w.requestActivate()

    @Slot()
    def closeBall(self):
        """设置/长按确认里的「退出」：只关悬浮球，主程序继续跑"""
        if self.win is not None:
            self.win.close()


class FloatWindow:
    """在现有 engine 里再挂一个根对象（悬浮球窗口）。"""

    def __init__(self, engine, base_dir, main_win):
        self._engine = engine
        self._base = base_dir
        self._bridge = _FloatBridge(main_win)
        self.win = None

    def start(self, no_activate=True, hide_taskbar=True):
        # ⚠️ 必须在 load **之前**设好：窗口创建后再改 flags 会让 Qt 重建窗口（遮罩会丢）
        self._engine.rootContext().setContextProperty("floatNoActivateCtx", bool(no_activate))
        self._engine.rootContext().setContextProperty("floatBridge", self._bridge)

        before = len(self._engine.rootObjects())
        self._engine.load(QUrl.fromLocalFile(os.path.join(self._base, 'qml', 'float', 'FloatBall.qml')))
        roots = self._engine.rootObjects()
        if len(roots) <= before:
            return False          # QML 加载失败（错误已由 message handler 记录）
        win = roots[-1]
        self.win = win
        self._bridge.win = win

        if hide_taskbar:
            try:
                hwnd = int(win.winId())
                u = ctypes.windll.user32
                u.GetWindowLongPtrW.restype = ctypes.c_longlong
                u.SetWindowLongPtrW.restype = ctypes.c_longlong
                u.SetWindowLongPtrW(hwnd, -20, u.GetWindowLongPtrW(hwnd, -20) | 0x00000080)  # WS_EX_TOOLWINDOW
            except Exception:
                pass

        self._apply_mask()
        try:
            win.maskVersionChanged.connect(self._apply_mask)
            win.maskModeChanged.connect(self._apply_mask)
            win.widthChanged.connect(self._apply_mask)
            win.heightChanged.connect(self._apply_mask)
        except Exception:
            pass
        return True

    def _apply_mask(self):
        """窗口形状：球态只留球、气泡态留球+四泡、卡片态整窗。形状外点击穿透。"""
        win = self.win
        if win is None:
            return
        try:
            mode = int(win.property("maskMode") or 0)
            bx = BALL_OFF[0] + BALL_SIZE // 2
            by = BALL_OFF[1] + BALL_SIZE // 2
            if mode == 0:
                reg = _circle(bx, by, BALL_SIZE // 2 + 2)
            elif mode == 1:
                reg = _circle(bx, by, BALL_SIZE // 2 + 2)
                for ox, oy in BUBBLE_OFFS:
                    reg = reg.united(_circle(bx + ox, by + oy, BUBBLE_SIZE // 2 + 2))
            else:
                reg = QRegion(0, 0, int(win.width()), int(win.height()))
            win.setMask(reg)
        except Exception:
            pass
