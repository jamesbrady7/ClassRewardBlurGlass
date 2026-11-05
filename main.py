# ============================================================
# 文件功能：应用入口（PySide6 + QML）
# 对应Tab：全部
# 依赖库：PySide6, controller, model, qml_bridge, qml_theme
# 使用方法：python main.py 或 双击启动器
#
# 架构：model / controller 是纯 Python（MVC 数据层与业务层，不碰 Qt），
#       QML 是视图层，通过 qml_bridge 的 View-Model 适配器交互。
#
# 毛玻璃：窗口为无边框 + 透明，背景由 **Windows DWM Acrylic** 在窗后实时糊化桌面
#         （见下方 _apply_accent）。GLASS_SYSTEM=0 可关闭，退回原来的自绘渐变底。
# ============================================================
import ctypes
import os
import platform
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def _res_base():
    """资源目录（QML / 字体 / 图标）：源码运行=项目根；打包后=PyInstaller 解包目录"""
    if getattr(sys, 'frozen', False):
        return getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


def _app_base():
    """数据目录：源码运行=项目根；打包后=exe 所在目录"""
    return os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) \
        else os.path.dirname(os.path.abspath(__file__))


BASE = _res_base()
DATA_BASE = _app_base()
# 日志写到数据目录（打包后别落进 onefile 的临时解包目录，否则进程结束就没了）
_logFile = os.path.join(DATA_BASE, '_run.log')

# 桌面穿透开关（默认开；GLASS_SYSTEM=0 可关，退回自绘底）
SYSTEM_GLASS = os.environ.get('GLASS_SYSTEM', '1') == '1'
GLASS_SKIP_REASON = ''

_LOG_MAX = 512 * 1024
_log_repeat = {'last': None, 'n': 0}
_shutting_down = False


def _log(line):
    """统一落盘。同一行连续重复时只记一次并合并计数（QML 逐帧报错会把日志刷爆）。"""
    if line == _log_repeat['last']:
        _log_repeat['n'] += 1
        return
    tail = ''
    if _log_repeat['n'] > 1:
        tail = '  ↑ 上一行重复 %d 次\n' % (_log_repeat['n'] - 1)
    _log_repeat['last'] = line
    _log_repeat['n'] = 1
    try:
        if os.path.exists(_logFile) and os.path.getsize(_logFile) > _LOG_MAX:
            os.replace(_logFile, _logFile + '.1')
    except OSError:
        pass
    try:
        with open(_logFile, 'a', encoding='utf-8') as f:
            f.write(tail + line + '\n')
    except OSError:
        pass


def _acrylic_ok():
    """Acrylic 状态4 自 Win10 1803(17134) 起可用。"""
    try:
        return sys.getwindowsversion().build >= 17134
    except Exception:
        return False


def _transparency_enabled():
    """系统『透明效果』开关。关掉时 DWM 直接禁用 Acrylic——窗口仍透明但背景是锐利的，
    叠多少层都救不回来，所以必须退回自绘底。"""
    try:
        import winreg
        with winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') as k:
            return winreg.QueryValueEx(k, 'EnableTransparency')[0] == 1
    except Exception:
        return True      # 读不到就按"开"处理，别误伤


def _system_glass_ok():
    global GLASS_SKIP_REASON
    if not SYSTEM_GLASS:
        return False
    if not _acrylic_ok():
        GLASS_SKIP_REASON = '当前系统不支持（需要 Windows 10 1803 及以上）'
    elif not _transparency_enabled():
        GLASS_SKIP_REASON = '系统『透明效果』已关闭（设置 > 个性化 > 颜色）'
    else:
        return True
    _log('[glass] 桌面穿透跳过：%s → 退回自绘底' % GLASS_SKIP_REASON)
    return False


SYSTEM_GLASS_OK = _system_glass_ok()

if SYSTEM_GLASS_OK:
    # ⚠️ 不强制软件渲染：原型在同一哨兵底下 A/B 实测两个后端的 Acrylic 输出逐位相同，
    #    而软件渲染的动画只有硬件的 1/6（拖动/最小化会明显卡）。若某台机器上 Acrylic 真的不透，
    #    用 GLASS_BACKEND=software 退回。
    _backend = os.environ.get('GLASS_BACKEND', '')
    if _backend:
        os.environ['QT_QUICK_BACKEND'] = _backend

import PySide6
from PySide6.QtCore import (QAbstractNativeEventFilter, QEasingCurve, QEventLoop, QObject,
                            QPoint, QPropertyAnimation, QTimer, QUrl, Slot,
                            qInstallMessageHandler, qVersion)
from PySide6.QtGui import QGuiApplication, QIcon, QSurfaceFormat, QFont, QFontDatabase, QCursor
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQuickControls2 import QQuickStyle

# 启动动画/悬浮球都需要半透明窗口；主窗口本身也是透明圆角。
# 统一在创建任何窗口前打开 alpha（不再只限桌面穿透模式）。
QQuickWindow.setDefaultAlphaBuffer(True)
_fmt = QSurfaceFormat()
_fmt.setAlphaBufferSize(8)
QSurfaceFormat.setDefaultFormat(_fmt)

from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import PreviewPrefs, RewardBridge
from qml_theme import Theme

_FONT_WEIGHTS = ('Regular', 'Medium', 'Semibold', 'Bold')


def _qt_message(mode, context, message):
    # 退出阶段 QML 对象逐个销毁，绑定会读到已清空的 Theme/timerHub 并刷
    # "Cannot read property ... of null" —— 无害，但会把日志淹没，直接忽略。
    if _shutting_down:
        return
    _log(message)


def _build_no():
    try:
        return sys.getwindowsversion().build
    except Exception:
        return 0


def _needs_throttle():
    """**只有 Win10 需要给"改窗口几何"的操作节流**（拖动 + 拉边缩放）
    —— 按系统版本适配，两边各取各自最好的那个。

    Win10：系统移动循环把鼠标**每个输入事件**变成一次窗口移动，acrylic 每步都要重算
           整窗模糊 → DWM 饱和、窗口跟不上光标 → 必须节流跟随（代价：失去吸附）。
    Win11：走另一条合成路径，原生拖动本来就跟手，且能保住 Snap Layouts / 贴边 /
           高刷拖动 → **不要节流**，用系统原生的。

    下限 17134 与 _acrylic_ok 一致：更低版本没有 Acrylic，也就没有要保护的东西。
    """
    b = _build_no()
    return 17134 <= b < 22000


def _accent_params():
    """按系统版本返回 (AccentState, AccentFlags, GradientColor)。

    ⚠️ 状态号必须与 flags 配对，跨状态套用别的参数会得到"零模糊"的假象：
      Win11(>=22000)：状态3 + 零 flags/零染色 —— 只模糊、不掺系统白纱，最透
      Win10(<22000) ：状态4 + flags2 —— Win10 上状态3 不出真模糊，状态4 才有
    """
    if _build_no() >= 22000:
        return 3, 0, 0x00000000
    return 4, 2, 0x00F6EEE8


def _apply_accent(hwnd):
    """无边框窗 Acrylic：SetWindowCompositionAttribute + 系统圆角。"""
    class _ACCENT_POLICY(ctypes.Structure):
        _fields_ = [('AccentState', ctypes.c_int), ('AccentFlags', ctypes.c_int),
                    ('GradientColor', ctypes.c_uint), ('AnimationId', ctypes.c_int)]

    class _WINCOMPATTRDATA(ctypes.Structure):
        _fields_ = [('Attribute', ctypes.c_int),
                    ('Data', ctypes.POINTER(_ACCENT_POLICY)),
                    ('SizeOfData', ctypes.c_size_t)]

    st, flags, grad = _accent_params()
    policy = _ACCENT_POLICY(st, flags, grad, 0)
    data = _WINCOMPATTRDATA(19, ctypes.pointer(policy), ctypes.sizeof(policy))
    ctypes.windll.user32.SetWindowCompositionAttribute(hwnd, ctypes.byref(data))

    corner = ctypes.c_int(2)      # DWMWCP_ROUND
    ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, 33, ctypes.byref(corner), 4)


def _set_topmost(hwnd, on):
    """无破窗地切换置顶（SetWindowPos，不改 Qt flags，避免窗口重建/闪烁）。"""
    try:
        user32 = ctypes.windll.user32
        user32.SetWindowPos.argtypes = [
            ctypes.c_void_p, ctypes.c_void_p,
            ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_uint]
        user32.SetWindowPos.restype = ctypes.c_int
        ok = user32.SetWindowPos(
            ctypes.c_void_p(int(hwnd)),
            ctypes.c_void_p(-1 if on else -2),     # HWND_TOPMOST / HWND_NOTOPMOST
            0, 0, 0, 0,
            0x0001 | 0x0002 | 0x0010)              # NOSIZE | NOMOVE | NOACTIVATE
        _log("[window] topmost=%s hwnd=%s ok=%s" % (on, hwnd, ok))
        return bool(ok)
    except Exception as e:
        _log("[window] topmost 设置失败：%r" % (e,))
        return False


DRAG_HZ = max(1, int(os.environ.get("GLASS_DRAG_HZ", "60")))   # 拖动跟随频率


class _GlassDrag(QObject):
    """自管理拖动：由 QML 传入**点击/触摸的屏幕坐标**驱动窗口移动。

    ⚠️ 不能用 QCursor.pos()：学校一体机是触摸屏，QCursor 是"最后一个鼠标位置"，
       手指触摸时它不会跟着手指走 → 主窗一按就按旧鼠标位置跳走、悬浮球拖拽
       鼠标"跑到窗口中间"。QML 把 MouseArea 的点击点映射到屏幕坐标传进来，
       鼠标和手指都跟随真实触点。

    坐标全是 Qt 逻辑像素（QML 的 win.x + mapToItem(null)），与 DPI 无关。
    自绘节流到 DRAG_HZ；松手判定 QML onReleased + mouseGrabberItem() 兜底。
    GLASS_DRAG=system 可退回系统拖动；GLASS_DRAG_HZ 可调跟随频率。
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._win = None
        self._custom = True
        self._origin = None      # (窗体x, 窗体y, 触点x, 触点y) 全是 Qt 逻辑像素
        self._target = None      # 最新触点屏幕坐标
        self._startedAt = 0.0
        self._ticks = 0
        self._timer = QTimer(self)
        self._timer.setInterval(max(8, int(1000 / DRAG_HZ)))
        self._timer.timeout.connect(self._tick)

    def attach(self, win, custom=True):
        self._win = win
        self._custom = bool(custom)
        _log("[drag] 拖动模式：%s"
             % ("自绘跟随 %dHz（QML 触点绝对位移）" % DRAG_HZ
                if custom else "系统 startSystemMove（GLASS_DRAG=system）"))

    @Slot(result="QPoint")
    def cursorPos(self):
        """兼容旧调用：仅用于非触摸的辅助位置，不参与拖动/缩放。"""
        return QCursor.pos()

    @Slot()
    def start(self):
        c = QCursor.pos()
        self.startAt(c.x(), c.y())

    @Slot(float, float)
    def startAt(self, x, y):
        if self._win is None:
            return
        if not self._custom:
            self._win.startSystemMove()
            return
        p = self._win.position()
        self._origin = (p.x(), p.y(), float(x), float(y))
        self._target = (float(x), float(y))
        self._startedAt = time.monotonic()
        self._ticks = 0
        _log("[drag] start win=(%d,%d) touch=(%.0f,%.0f) dpr=%.2f"
             % (p.x(), p.y(), x, y, self._win.devicePixelRatio() or 1.0))
        self._timer.start()

    @Slot(float, float)
    def moveTo(self, x, y):
        self._target = (float(x), float(y))

    def _tick(self):
        w = self._win
        if w is None or self._origin is None or self._target is None:
            self._timer.stop()
            return
        # 0.15s 宽限期：刚开始拖动/窗口还没稳定时不要误判
        if time.monotonic() - self._startedAt > 0.15:
            try:
                if w.mouseGrabberItem() is None:      # QML MouseArea 已松手
                    self._stop()
                    return
            except Exception:
                pass
        ox, oy, sx, sy = self._origin
        tx, ty = self._target
        nx = ox + (tx - sx)
        ny = oy + (ty - sy)
        # 至少留 160px 宽 + 顶部 80px 的标题栏，避免拖成"只剩右下角"
        try:
            scr = QGuiApplication.screenAt(QPoint(int(tx), int(ty)))
            if scr is not None:
                g = scr.geometry()
                ww = w.width()
                cx_ok = max(g.left() - ww + 160, min(nx, g.right() - 160))
                cy_ok = max(g.top(), min(ny, g.bottom() - 80))
                if (cx_ok, cy_ok) != (nx, ny) and self._ticks <= 1:
                    _log("[drag] 边界限制 (%d,%d) -> (%d,%d) screen=%s"
                         % (nx, ny, cx_ok, cy_ok, scr.name()))
                nx, ny = cx_ok, cy_ok
        except Exception:
            pass
        w.setPosition(round(nx), round(ny))
        self._ticks += 1
        if self._ticks == 1:
            _log("[drag] first move -> win=(%d,%d) touch=(%.0f,%.0f)"
                 % (w.x(), w.y(), tx, ty))
        if self._ticks > DRAG_HZ * 120:              # 2 分钟安全上限
            self._stop()

    def _stop(self):
        if self._timer.isActive():
            _log("[drag] stop ticks=%d win=(%d,%d)"
                 % (self._ticks, self._win.x() if self._win else -1,
                    self._win.y() if self._win else -1))
        self._timer.stop()

    @Slot()
    def stop(self):
        """QML 松开鼠标时调用（正常路径）。"""
        self._stop()


class _AppControl(QObject):
    """托盘 / 主窗口共用的退出入口。

    统一走这里的目的：保证关闭的是**整个进程**（主窗口 + 隐藏的悬浮球 + 启动页），
    否则窗口看似关了、进程还在，U 盘上的 exe 就一直被占用。
    """

    @Slot()
    def quitApp(self):
        _log("[app] 收到退出请求（托盘/主窗口）")
        app = QGuiApplication.instance()
        if app is not None:
            # ⚠️ 必须用 exit(0) 而不是 quit()：本应用（Qt 6.11 + 多个 QML Window）
            #    实测 quit() 不会让 app.exec() 返回，进程会一直挂着、占住 U 盘上的 exe；
            #    exit(0) 才能确实结束主事件循环（离屏探针已验证）。
            app.exit(0)


_SINGLE_MUTEX = None


def _single_instance_guard():
    """同名互斥体：防止重复启动多个进程分别占用 exe。

    已有一个实例时不静默退出——先把现有窗口叫到前台；
    找不到窗口就弹系统提示，告诉用户从托盘「彻底退出」。
    GLASS_SINGLE_INSTANCE=0 可跳过（仅用于开发机同时跑源码/打包版做对比）。
    """
    global _SINGLE_MUTEX
    if os.environ.get('GLASS_SINGLE_INSTANCE') == '0':
        _log('[app] 单实例检查已跳过（GLASS_SINGLE_INSTANCE=0）')
        return True
    try:
        k32 = ctypes.windll.kernel32
        k32.CreateMutexW.restype = ctypes.c_void_p
        _SINGLE_MUTEX = k32.CreateMutexW(None, False, "ClassRewardHelper.SingleInstance")
        if k32.GetLastError() != 183:          # ERROR_ALREADY_EXISTS
            return True
        u32 = ctypes.windll.user32
        hwnd = u32.FindWindowW(None, "班级激励助手")
        if hwnd:
            u32.ShowWindow(hwnd, 9)            # SW_RESTORE
            u32.SetForegroundWindow(hwnd)
        else:
            u32.MessageBoxW(
                None,
                "班级激励助手已经在运行。\n\n"
                "请在系统托盘图标上右键选择「彻底退出」，\n"
                "或先在任务管理器里结束残留的「班级激励助手」进程。",
                "班级激励助手", 0x40)          # MB_ICONINFORMATION
        return False
    except Exception as e:
        _log("[app] 单实例检查失败：%r" % (e,))
        return True


WM_SYSCOMMAND = 0x0112
SC_MINIMIZE = 0xF020


class _MSG(ctypes.Structure):
    _fields_ = [("hwnd", ctypes.c_void_p), ("message", ctypes.c_uint),
                ("wParam", ctypes.c_size_t), ("lParam", ctypes.c_ssize_t),
                ("time", ctypes.c_uint), ("pt", ctypes.c_long * 2)]


class _MinEventFilter(QAbstractNativeEventFilter):
    """拦 SC_MINIMIZE 的过滤器。

    ⚠️ 必须单独一个类：QAbstractNativeEventFilter 不是 QObject，没法让同一个对象
    既当 QML 的 context property、又当事件过滤器。让过滤器持有桥的引用转发即可。
    """

    def __init__(self, owner):
        super().__init__()
        self._owner = owner

    def nativeEventFilter(self, eventType, message):
        return self._owner.on_native_event(eventType, message)


class _MinimizeAnim(QObject):
    """最小化前的"柔和过渡"桥（照搬原型）。

    为什么需要：系统的窗口最小化/还原动画**对 WS_EX_LAYERED 窗口不生效**，而本窗口为了
    透明正是 layered 的 → 表现为"啪"地消失/出现（像 PPT 的"出现"效果）。
    做法：拦下 WM_SYSCOMMAND/SC_MINIMIZE，先让 QML 播一段"缩小 + 淡出"，
    播完（或超时兜底）再真正调用 showMinimized()。
    QML 侧通过 `mainWin.minimizing = true` 触发，播完回调本类的 finishMinimize()。

    顺带覆盖"点任务栏图标最小化"——那条路径发的也是 SC_MINIMIZE。
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._win = None
        self._winid = 0
        self._filter = None
        self._fallback = None

    def attach(self, win, app):
        self._win = win
        self._winid = int(win.winId())
        # ⚠️ 持引用：QAbstractNativeEventFilter 的临时对象被 GC 会**静默失效**
        self._filter = _MinEventFilter(self)
        app.installNativeEventFilter(self._filter)
        # 兜底：万一 QML 那段动画没回调（异常/被中断），600ms 后照样最小化，
        # 否则窗口会卡在"拦截了但没最小化"的状态——这是拦系统消息必须留的保险
        self._fallback = QTimer(self)
        self._fallback.setSingleShot(True)
        self._fallback.timeout.connect(self.finishMinimize)

    def on_native_event(self, eventType, message):
        """由 _MinEventFilter 转发进来。"""
        if self._win is None or bytes(eventType) != b"windows_generic_MSG":
            return False, 0
        try:
            msg = ctypes.cast(int(message), ctypes.POINTER(_MSG)).contents
        except Exception:
            return False, 0
        if (msg.message == WM_SYSCOMMAND and (msg.wParam & 0xFFF0) == SC_MINIMIZE
                and msg.hwnd == self._winid):
            self._start()
            return True, 0          # 拦下，不让系统立刻最小化
        return False, 0

    def _start(self):
        self._win.setProperty("minimizing", True)
        self._fallback.start(600)

    @Slot()
    def finishMinimize(self):
        if self._win is None:
            return
        self._fallback.stop()
        self._win.showMinimized()


def _load_fonts(base):
    """注册内置 MiSans 字体，返回家族名（失败返回 None）"""
    fd = os.path.join(base, 'assets', 'fonts')
    family = None
    if os.path.isdir(fd):
        for w in _FONT_WEIGHTS:
            p = os.path.join(fd, f'MiSans-{w}.ttf')
            if os.path.exists(p):
                fid = QFontDatabase.addApplicationFont(p)
                fams = QFontDatabase.applicationFontFamilies(fid) if fid >= 0 else []
                if fams and family is None:
                    family = fams[0]
    return family


def main():
    # 单实例：重复启动时不再产生第二个进程（避免 exe 被多进程占用、U 盘弹不出）
    if not _single_instance_guard():
        sys.exit(0)

    qInstallMessageHandler(_qt_message)
    # Windows 原生 Controls 样式不支持自定义 background/contentItem（细滚动条会被忽略并刷警告）。
    # 全站用 Basic 样式，才能让 ThinScrollBar 和自绘 ToolTip/Popup 真正生效。
    try:
        QQuickStyle.setStyle("Basic")
    except Exception as e:
        _log('[ui] QtQuick Controls Basic 样式设置失败：%r' % (e,))
    app = QGuiApplication(sys.argv)
    app.setApplicationName("班级激励助手")
    app.setOrganizationName("ClassReward")
    # 让任务栏把本进程当成独立应用（否则源码运行时容易显示 Python 的图标/分组）
    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
            "ClassRewardHelper.V316")
    except Exception:
        pass
    # 应用图标（窗口 / 任务栏 / 快捷方式）：与标题栏左上角同一套 marine + 白四芒星
    try:
        _icon = os.path.join(_res_base(), 'assets', 'app_icon.ico')
        if os.path.exists(_icon):
            app.setWindowIcon(QIcon(_icon))
    except Exception as e:
        _log('[icon] 应用图标加载失败：%r' % (e,))

    # 悬浮卡片可以整体缩放 → 文字改用曲线渲染，按矢量重绘，放大也不糊。
    # 必须在创建任何 QQuickWindow 之前设置。
    try:
        QQuickWindow.setTextRenderType(QQuickWindow.CurveTextRendering)
    except Exception as e:
        _log('[text] 曲线文字渲染不可用：%r' % (e,))

    base = _app_base()      # 数据（班级 JSON / 日志）
    res = _res_base()       # 资源（QML / 字体 / 图标）

    # 注册内置 MiSans 字体（成功则全局用它；失败回退微软雅黑）
    family = _load_fonts(res)
    app.setFont(QFont(family or 'Microsoft YaHei', 13))

    # ── 环境诊断日志：学校机器出问题时，这些信息决定能不能远程定位 ──
    try:
        _log('[sys] platform=%s' % platform.platform())
        _log('[sys] windows=%r' % (sys.getwindowsversion(),))
        _log('[sys] qt=%s pyside=%s frozen=%s' % (qVersion(), PySide6.__version__,
                                                 getattr(sys, 'frozen', False)))
        _log('[sys] app_dir=%s res_dir=%s' % (base, res))
        try:
            _src = sys.executable if getattr(sys, 'frozen', False) else os.path.abspath(__file__)
            _log('[sys] build_mtime=%s'
                 % time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(os.path.getmtime(_src))))
        except Exception:
            pass
        _log('[sys] qt_graphics_api=%s'
             % QQuickWindow.graphicsApi())
        _log('[sys] transparency=%s acrylic_ok=%s drag_hz=%d glass=%s drag_mode=%s'
             % (_transparency_enabled(), _acrylic_ok(), DRAG_HZ,
                os.environ.get('GLASS_BACKEND', 'default'),
                os.environ.get('GLASS_DRAG', 'custom')))
        for s in QGuiApplication.screens():
            g = s.geometry(); a = s.availableGeometry()
            _log('[sys] screen "%s" geo=(%d,%d %dx%d) avail=(%d,%d %dx%d) '
                 'dpr=%.2f primary=%s'
                 % (s.name(), g.x(), g.y(), g.width(), g.height(),
                    a.x(), a.y(), a.width(), a.height(),
                    s.devicePixelRatio(), s is QGuiApplication.primaryScreen()))
        try:
            u = ctypes.windll.user32
            vx = u.GetSystemMetrics(76); vy = u.GetSystemMetrics(77)
            vw = u.GetSystemMetrics(78); vh = u.GetSystemMetrics(79)
            _log('[sys] virtual_desktop=(%d,%d %dx%d)' % (vx, vy, vw, vh))
        except Exception:
            pass
    except Exception as e:
        _log('[sys] 环境信息收集失败：%r' % (e,))

    # MVC：controller 持数据，bridge 是 View-Model 适配器
    storage = StorageManager(os.path.join(base, 'class_reward_data.json'))
    ctrl = AppController(storage)
    bridge = RewardBridge(ctrl)

    engine = QQmlApplicationEngine()
    # 必须持有 Python 引用，否则对象被 GC，QML 里读到 null
    theme = Theme()
    # context property 必须在 load 之前注册；窗口对象要 load 之后才有，故先建后 attach
    glass_drag = _GlassDrag()
    engine.rootContext().setContextProperty("glassDrag", glass_drag)
    minimize_anim = _MinimizeAnim()
    engine.rootContext().setContextProperty("glassWin", minimize_anim)
    engine.rootContext().setContextProperty("reward", bridge)
    engine.rootContext().setContextProperty("Theme", theme)
    # 今日分数预览窗口的持久化设置（置顶开关）：QSettings 存本机，重启/拔 U 盘后仍生效
    preview_prefs = PreviewPrefs()
    engine.rootContext().setContextProperty("scorePrefs", preview_prefs)
    # 托盘 / 主窗口统一退出入口（必须持有引用，避免被 GC）
    app_control = _AppControl()
    engine.rootContext().setContextProperty("appControl", app_control)
    # QML 按它决定：桌面穿透模式（背景交给 DWM）还是自绘底
    engine.rootContext().setContextProperty("systemGlass", SYSTEM_GLASS_OK)
    # QML 按它决定：改窗口几何的操作（拖动 / 拉边缩放）要不要节流 —— 只有 Win10 需要。
    # GLASS_DRAG=system 同时关掉两者（都退回原生的逐事件行为，便于 A/B）。
    engine.rootContext().setContextProperty(
        "glassThrottle",
        SYSTEM_GLASS_OK and _needs_throttle() and os.environ.get("GLASS_DRAG") != "system")
    # 悬浮球持久化配置（卡片缩放等）：QML 在 onCompleted 里读取
    try:
        from float_window import FloatPrefs
        float_prefs = FloatPrefs()
        engine.rootContext().setContextProperty("floatPrefs", float_prefs)
    except Exception as e:
        _log('[float] 配置初始化失败：%r' % (e,))

    # ── 启动动画窗口：先建、先上屏 ──
    #    主界面 QML 加载要几百毫秒；这段时间让用户看到"静止的悬浮球"，
    #    而不是空桌面/半成品窗口。主界面在它背后加载，就绪后再播点击涟漪。
    splash = None
    splash_comp = None
    try:
        splash_comp = QQmlComponent(
            engine, QUrl.fromLocalFile(os.path.join(res, 'qml', 'Splash.qml')))
        splash = splash_comp.create()
        if splash is None:
            _log('[splash] 创建失败：' + splash_comp.errorString())
        else:
            splash.show()
            # 强制把第一帧（含 Canvas 画的球）渲染出来，再开始加载主界面；
            # 否则主界面加载期间会看到一块纯黑幕布。
            try:
                splash.grabWindow()
            except Exception:
                pass
            # ⚠️ processEvents 不驱动 QQuickWindow 的首帧；这里跑一个很短的真事件循环，
            # 让启动幕布真正上屏后再加载主界面（加载会阻塞 UI 线程）。
            _loop = QEventLoop()
            QTimer.singleShot(180, _loop.quit)
            _loop.exec()
    except Exception as e:
        _log('[splash] 初始化失败：%r' % (e,))

    engine.load(QUrl.fromLocalFile(os.path.join(res, 'qml', 'Main.qml')))
    roots = engine.rootObjects()
    if not roots:
        _log('[glass] QML 加载失败')
        sys.exit(1)
    # 图形后端已在上面用 QQuickWindow.graphicsApi() 记录（Qt 6 的
    # QSGRendererInterface 在 PySide 里不是静态调用，别再传 window 进去）

    # 最小化过渡：窗口本身透明（layered），系统的最小化动画对它不生效 → 自己播一段。
    # 与是否桌面穿透无关，两种模式都要装。
    minimize_anim.attach(roots[0], app)

    # 两条系统路径都兜住：默认一律走自绘拖动（按屏幕光标绝对位移），
    # 只有显式 GLASS_DRAG=system 才交给系统 startSystemMove。
    # （学校 Win10 + 非 100% 缩放 / 副屏，原来那套物理像素换算会拖不动或乱跳）
    glass_drag.attach(roots[0], os.environ.get("GLASS_DRAG") != "system")

    if SYSTEM_GLASS_OK:
        try:
            hwnd = int(roots[0].winId())
            _apply_accent(hwnd)
            st, flags, grad = _accent_params()
            _log('[glass] 桌面穿透已启用：build=%s state=%d flags=%d grad=0x%08X'
                 % (getattr(sys.getwindowsversion(), 'build', '?'), st, flags, grad))
        except Exception as e:
            # pythonw 无控制台，print 到 stderr 等于把失败扔进虚空
            _log('[glass] Acrylic 应用失败：%r' % (e,))

    # ── 共享计时器：主界面「工具箱」和悬浮球必须是同一个对象 ──
    #    实例在 Main.qml 里（property timerHub），这里把它交给悬浮球窗口的
    #    QML 作用域；必须在 FloatWindow.start()（加载悬浮球 QML）之前注册。
    try:
        timer_hub = roots[0].property("timerHub")
        if timer_hub is None:
            _log('[timer] Main.qml 未暴露 timerHub，悬浮球计时将不可用')
        else:
            engine.rootContext().setContextProperty('timerHub', timer_hub)
    except Exception as e:
        _log('[timer] 共享计时器注册失败：%r' % (e,))

    # ── 课堂快捷悬浮球：在主窗口之外再挂一个窗口（同进程 → 共用数据，调主界面秒开）──
    #    设置里的「退出悬浮球」只关它自己，主程序继续运行。
    float_win = None
    try:
        from float_window import FloatWindow
        float_win = FloatWindow(engine, res, roots[0], log=_log)
        if not float_win.start():
            _log('[float] 悬浮球 QML 加载失败')
        else:
            _log('[float] 悬浮球已启动')
    except Exception as e:
        float_win = None
        _log('[float] 悬浮球启动失败：%r' % (e,))

    # ── 退出清理：不管从主窗口 X、悬浮球退出还是托盘「彻底退出」，都保证 ──
    #    主窗 + 悬浮球 + 启动页全部关掉，事件循环真正返回，onefile 的父子进程
    #    才会一起结束、释放 U 盘上的 exe。
    #    ⚠️ 不要在主窗口的 closing 信号里关悬浮球：用户点 X 后如果点了「取消」，
    #       悬浮球会被误关（原实现的问题）。
    def _cleanup_before_quit():
        global _shutting_down
        _shutting_down = True          # 之后 QML 销毁阶段的 null 告警不再进日志
        _log('[app] aboutToQuit：关闭全部窗口')
        try:
            if float_win is not None and float_win.win is not None:
                float_win.win.close()
        except Exception as e:
            _log('[app] 关闭悬浮球失败：%r' % (e,))
        try:
            if splash is not None:
                splash.close()
        except Exception as e:
            _log('[app] 关闭启动页失败：%r' % (e,))

    app.aboutToQuit.connect(_cleanup_before_quit)

    # ── 启动动画收尾：透明底悬浮球 + 点击涟漪 ──
    #    启动页只显示球本身（透明窗口），主界面保持隐藏；
    #    动画结束后再 show 主界面（主界面已在后台完成 QML 加载）。
    main_win = roots[0]
    _anim_refs = []          # QPropertyAnimation 必须持引用
    _presented = [False]

    def _fade_in_main():
        try:
            anim = QPropertyAnimation(main_win, b"opacity")
            anim.setDuration(260)
            anim.setStartValue(0.0)
            anim.setEndValue(1.0)
            anim.setEasingCurve(QEasingCurve.OutCubic)
            anim.finished.connect(lambda: main_win.setOpacity(1.0))
            _anim_refs.append(anim)
            anim.start()
        except Exception as e:
            _log('[splash] 主窗口淡入失败：%r' % (e,))
            try:
                main_win.setOpacity(1.0)
            except Exception:
                pass

    def _drop_topmost():
        try:
            _set_topmost(int(main_win.winId()), False)
        except Exception:
            pass

    def _present_main():
        if _presented[0]:
            return
        _presented[0] = True
        try:
            # 先完全透明地显示并渲染，再整体淡入：
            # Acrylic 是窗口级效果，只把 contentItem 淡入挡不住"模糊底先出现"。
            main_win.setOpacity(0.0)
        except Exception as e:
            _log('[splash] 主窗口透明起步失败：%r' % (e,))
        try:
            main_win.show()
            # 启动弹出瞬间置顶，避免被其它窗口压住；淡入结束后恢复普通层级。
            # 用原生 SetWindowPos 而不是改 Qt flags，后者会重建窗口、闪一下。
            _set_topmost(int(main_win.winId()), True)
            QTimer.singleShot(1500, _drop_topmost)
            if SYSTEM_GLASS_OK:
                try:
                    _apply_accent(int(main_win.winId()))
                except Exception as e:
                    _log('[splash] Acrylic 重应用失败：%r' % (e,))
            main_win.raise_()
            main_win.requestActivate()
        except Exception as e:
            _log('[splash] 主窗口显示失败：%r' % (e,))
        QTimer.singleShot(140, _fade_in_main)

    def _on_splash_finished():
        _present_main()
        # 球还在做 180ms 的淡出；主窗已在背后用 opacity=0 渲染 → 交叉过渡
        if splash is not None:
            QTimer.singleShot(240, lambda: splash.hide())

    def _splash_fallback():
        # 动画异常没发 finished 时兜底；正常完成后 splash 已隐藏 → 不做任何事
        try:
            if splash is not None and splash.isVisible():
                _on_splash_finished()
        except Exception:
            pass

    if splash is not None:
        try:
            splash.finished.connect(_on_splash_finished)
            splash.setProperty('startRipple', True)
            QTimer.singleShot(5000, _splash_fallback)
        except Exception as e:
            _log('[splash] 启动动画启动失败：%r' % (e,))
            try:
                splash.hide()
            except Exception:
                pass
            _present_main()
    else:
        _present_main()

    # 诊断钩子：GLASS_AUTOQUIT_MS=3000 时自动退出（仅用于自动化验证退出/清理链路）
    _autoquit = os.environ.get('GLASS_AUTOQUIT_MS')
    if _autoquit:
        def _auto_quit():
            _log('[app] 测试钩子触发 appControl.quitApp()')
            app_control.quitApp()
        _log('[app] 测试钩子：%sms 后自动退出' % _autoquit)
        QTimer.singleShot(int(_autoquit), _auto_quit)

    rc = app.exec()
    _log('[app] 事件循环已退出 rc=%d，进程即将结束' % rc)
    sys.exit(rc)


if __name__ == '__main__':
    main()
