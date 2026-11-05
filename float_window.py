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

from PySide6.QtCore import Property, QObject, QSettings, QUrl, Slot
from PySide6.QtGui import QGuiApplication, QRegion

# 与 FloatBall.qml 里保持一致的两组几何（球/气泡态是 340 方窗、球居中）
BALL_OFF = (120, 120)
BALL_SIZE = 100
BUBBLE_OFFS = [(-74, 74), (-105, 0), (-74, -74), (0, -105)]
BUBBLE_SIZE = 68


def _circle(cx, cy, r):
    return QRegion(int(cx - r), int(cy - r), int(2 * r), int(2 * r), QRegion.Ellipse)


class FloatPrefs(QObject):
    """悬浮球的持久化小配置（目前只有卡片缩放），走 QSettings，重启后恢复。"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._s = QSettings()

    @Property(float, constant=True)
    def cardScale(self):
        try:
            # 0.48 = 原最小 0.8 的 60%（用户要求再小 40%）
            return max(0.48, min(1.3, float(self._s.value("float/cardScale", 1.0))))
        except Exception:
            return 1.0

    @Slot(float)
    def saveCardScale(self, v):
        try:
            self._s.setValue("float/cardScale", max(0.48, min(1.3, float(v))))
            self._s.sync()
        except Exception:
            pass


class _FloatBridge(QObject):
    """给悬浮球 QML / 主界面 QML 用的模式切换接口。

    真正的窗口操作在 FloatWindow 上（遮罩、窗口可见性都归它管），这里只做转发；
    owner 为空时（_float_test.py 独立跑）退化成"只管这一个窗口"的简单行为。
    """

    def __init__(self, main_win, owner=None, parent=None):
        super().__init__(parent)
        self._main = main_win
        self._owner = owner
        self.win = None

    @Slot()
    def enterFloatMode(self):
        """主界面左下角「进入悬浮球模式」：收起主窗口，只把球浮在桌面最上层。"""
        if self._owner is not None:
            self._owner.enter_float_mode()
            return
        w = self.win
        if w is not None:
            w.show()
            w.raise_()

    @Slot()
    def showMain(self):
        """气泡①「软件主界面」：回到主窗口（同进程，秒开），并把球收起来。"""
        if self._owner is not None:
            self._owner.return_to_main()
            return
        if self.win is not None:
            self.win.hide()

    @Slot()
    def closeBall(self):
        """设置/长按确认里的「退出」：退出悬浮球模式，回到主程序。

        主程序场景 = 收起球并把主窗口放回来（主窗口可能正被悬浮球模式藏着）；
        独立测试场景没有主窗口 → 直接关掉，避免留下一个没有入口的空进程。
        """
        if self._owner is not None:
            self._owner.return_to_main()
            return
        if self.win is not None:
            self.win.close()

    @Slot()
    def quitApp(self):
        """关闭气泡里的「退出」：确认后退出整个软件（主程序 + 悬浮球）。

        直接 quit，不再走主窗口的关闭确认——用户在悬浮球里已经确认过一次了。
        """
        app = QGuiApplication.instance()
        if app is not None:
            # ⚠️ 用 exit(0) 而不是 quit()：quit() 在多个 QML Window 下实测
            #    不会让 app.exec() 返回，进程会残留并占住 exe（U 盘弹不出）。
            app.exit(0)


class FloatWindow:
    """在现有 engine 里再挂一个根对象（悬浮球窗口）。"""

    def __init__(self, engine, base_dir, main_win, log=None):
        self._engine = engine
        self._base = base_dir
        self._main = main_win
        self._bridge = _FloatBridge(main_win, owner=self)
        self._log = log or (lambda *_a, **_k: None)
        self._last_mask_mode = None
        self._last_sign = None
        self._last_dpr = None
        self.win = None
        # 同一使用期间记住球的位置：回主界面时存，再次进入时恢复（不跨进程持久化）
        self._ball_pos = None

    # ── 模式切换（主界面左下角按钮 / 球上的气泡）──
    def enter_float_mode(self):
        """收起主窗口，只留球。

        ⚠️ 只有**确认球已经真的显示出来**才收起主窗口：
        否则一旦悬浮球窗口出问题（QML 加载失败 → win 为空、或被系统拒绝显示），
        主窗口一隐藏，"最后一个窗口关闭" → 整个应用直接退出，用户看到的就是"进了悬浮球模式就没了"。
        """
        self._show_ball()
        shown = self.win is not None and self.win.isVisible()
        self._log("[float] enter_float_mode: 球可见=%s" % shown)
        if self._main is not None and shown:
            try:
                self._log("[float] 隐藏主窗 x=%d y=%d %dx%d"
                          % (self._main.x(), self._main.y(),
                             self._main.width(), self._main.height()))
            except Exception:
                pass
            self._main.hide()
        elif self._main is not None:
            # 球没起来 → 主窗口保持在前，至少还能用；并把问题写进日志
            self._log("[float] 悬浮球未能显示，保持主窗口（不收起）")

    def return_to_main(self):
        """回到主窗口，并把球收起来。"""
        w = self._main
        if w is None:
            return
        try:
            self._log("[float] return_to_main: before x=%d y=%d %dx%d visible=%s"
                      % (w.x(), w.y(), w.width(), w.height(), w.isVisible()))
        except Exception:
            pass
        w.show()
        # 主窗可能在多屏/DPI 切换后被系统放到了屏幕外（只剩右下角、无法拖动）。
        # 这里再用当前屏幕做一次兜底校正，保证标题栏一定够得着。
        try:
            self._ensure_main_visible()
        except Exception as e:
            self._log("[float] 主窗位置检查失败：%r" % (e,))
        w.raise_()
        w.requestActivate()
        if not w.isVisible():
            print('[float] 主窗口未能显示，保留悬浮球', flush=True)
            return
        self._hide_ball()

    def _ensure_main_visible(self):
        w = self._main
        if w is None:
            return
        scr = w.screen() or QGuiApplication.primaryScreen()
        if scr is None:
            return
        g = scr.availableGeometry()
        x, y = w.x(), w.y()
        ww, wh = w.width(), w.height()
        top_ok = (y + 82 > g.top()) and (y < g.bottom() - 40)
        x_ok = (x + ww > g.left() + 120) and (x < g.right() - 120)
        self._log("[float] return_to_main: 主窗 x=%d y=%d %dx%d screen=%s "
                  "avail=(%d,%d %dx%d) title_visible=%s"
                  % (x, y, ww, wh, scr.name(), g.x(), g.y(), g.width(),
                     g.height(), top_ok and x_ok))
        if not (top_ok and x_ok):
            nx = g.x() + (g.width() - ww) // 2
            ny = g.y() + (g.height() - wh) // 2
            w.setPosition(nx, ny)
            self._log("[float] 主窗越界 → 重新居中 (%d,%d)" % (nx, ny))

    def _set_topmost(self, w):
        """悬浮球/小窗口始终置顶（QML flags 已带 StaysOnTop，这里再原生兜一次）。"""
        try:
            u = ctypes.windll.user32
            u.SetWindowPos.argtypes = [
                ctypes.c_void_p, ctypes.c_void_p,
                ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_uint]
            u.SetWindowPos.restype = ctypes.c_int
            ok = u.SetWindowPos(
                ctypes.c_void_p(int(w.winId())), ctypes.c_void_p(-1),
                0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010)
            self._log("[float] topmost ok=%s" % ok)
        except Exception as e:
            self._log("[float] topmost 设置失败：%r" % (e,))

    def _show_ball(self):
        w = self.win
        if w is None:
            return
        # 清掉上次长按残留的进度环状态，否则重新出现时会闪一下"进度条读完"的球
        try:
            w.setProperty("holdP", 0)
        except Exception:
            pass
        # 恢复到回主界面之前的位置（同一使用期间一致；不跨进程持久化）
        if self._ball_pos is not None:
            try:
                w.setProperty("ballX", self._ball_pos[0])
                w.setProperty("ballY", self._ball_pos[1])
            except Exception:
                pass
        # 上次退出时停在卡片页的话，下次进来要从"球"开始（否则一进来就是设置页）
        w.setProperty("mode", 0)
        w.show()
        w.raise_()
        self._set_topmost(w)
        self._apply_mask()

    def _hide_ball(self):
        w = self.win
        if w is None:
            return
        # 记住球当前的位置；下次 _show_ball 原样恢复
        try:
            self._ball_pos = (float(w.property("ballX")), float(w.property("ballY")))
        except Exception:
            pass
        w.setProperty("mode", 0)      # 下次进来从球态开始
        w.hide()

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
        # 悬浮球现在是"进入悬浮球模式"才出现的形态：启动时先收起，
        # 不跟主界面抢屏（主窗口左下角的按钮负责把它叫出来）。
        try:
            win.hide()
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
            # 窗口遮罩始终按球的边缘（52）；涟漪的同心圆裁切只在 QML Canvas 里做，
            # 绝不能把窗口遮罩缩到球以内，否则连悬浮球本身都会被切。
            changed = (mode != self._last_mask_mode)
            if changed:
                self._last_mask_mode = mode
            if mode == 0:
                reg = _circle(bx, by, BALL_SIZE // 2 + 2)
                win.setMask(reg)
                if changed:
                    self._log("[float] mask mode=0 %dx%d -> circle (mask_empty=%s)"
                              % (win.width(), win.height(), win.mask().isEmpty()))
            elif mode == 1:
                reg = _circle(bx, by, BALL_SIZE // 2 + 2)
                # 气泡可能镜像到另一侧（球靠近屏幕边时），遮罩要跟着同一组符号走
                try:
                    sx = 1 if int(win.property("bubbleSignX") or 1) >= 0 else -1
                    sy = 1 if int(win.property("bubbleSignY") or 1) >= 0 else -1
                except Exception:
                    sx, sy = 1, 1
                for ox, oy in BUBBLE_OFFS:
                    reg = reg.united(_circle(bx + ox * sx, by + oy * sy,
                                             BUBBLE_SIZE // 2 + 2))
                win.setMask(reg)
                dpr = win.devicePixelRatio() or 1.0
                if (changed or (sx, sy) != self._last_sign
                        or abs(dpr - (self._last_dpr or 0)) > 0.001):
                    self._last_sign = (sx, sy)
                    self._last_dpr = dpr
                    br = win.mask().boundingRect()
                    self._log(
                        "[float] mask mode=1 sign=(%d,%d) dpr=%.2f size=%dx%d "
                        "rects=%d bounds=(%d,%d %dx%d) empty=%s"
                        % (sx, sy, dpr, win.width(), win.height(),
                           len(win.mask()), br.x(), br.y(), br.width(), br.height(),
                           win.mask().isEmpty()))
            else:
                # 卡片态：整窗都可交互，不需要遮罩。
                # ⚠️ QQuickWindow 没有 clearMask()（C++ QWindow 有，PySide 没暴露；
                #    调用会抛 AttributeError，之前被 except 吞掉 → 圆形遮罩一直留着，
                #    卡片已经切出来却仍被裁成"圆球形状"）。
                # 正确清空方式：setMask(空 QRegion)。遮罩已空就不再重复设置。
                if not win.mask().isEmpty():
                    win.setMask(QRegion())
                if changed:
                    self._log("[float] mask mode=%d %dx%d -> full/cleared (mask_empty=%s)"
                              % (mode, win.width(), win.height(), win.mask().isEmpty()))
                return
        except Exception:
            pass
