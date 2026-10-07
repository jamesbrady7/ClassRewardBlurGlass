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
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BASE = os.path.dirname(os.path.abspath(__file__))
_logFile = os.path.join(BASE, '_run.log')

# 桌面穿透开关（默认开；GLASS_SYSTEM=0 可关，退回自绘底）
SYSTEM_GLASS = os.environ.get('GLASS_SYSTEM', '1') == '1'
GLASS_SKIP_REASON = ''

_LOG_MAX = 512 * 1024
_log_repeat = {'last': None, 'n': 0}


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

from PySide6.QtCore import (QAbstractNativeEventFilter, QObject, QTimer, QUrl, Slot,
                            qInstallMessageHandler)
from PySide6.QtGui import QGuiApplication, QSurfaceFormat, QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine

if SYSTEM_GLASS_OK:
    from PySide6.QtQuick import QQuickWindow
    QQuickWindow.setDefaultAlphaBuffer(True)     # 必须在窗口创建前
    _fmt = QSurfaceFormat()
    _fmt.setAlphaBufferSize(8)
    QSurfaceFormat.setDefaultFormat(_fmt)

from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

_FONT_WEIGHTS = ('Regular', 'Medium', 'Semibold', 'Bold')


def _qt_message(mode, context, message):
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


DRAG_HZ = max(1, int(os.environ.get("GLASS_DRAG_HZ", "60")))   # 拖动跟随频率
VK_LBUTTON = 0x01


class _GlassDrag(QObject):
    """自管理节流拖动，替代 QWindow.startSystemMove()。

    为什么不用系统拖动：它把鼠标的**每一个**输入事件都变成一次窗口移动。Win10 的
    acrylic 每移动一步都要重新模糊整个窗口表面 → DWM 被压饱和 → 窗体平滑地跟不上光标、
    且拖动期间应用无响应。

    自己按固定频率跟随光标，把移动次数压到 DRAG_HZ（默认 60），模糊得以保留。
    证据：用 SetWindowPos 驱动窗口的合成拖动（连 1000Hz 也不）在 acrylic 下不卡，
    说明"移动窗口"本身廉价，贵的是系统拖动那条路的每事件一次重绘。

    代价：失去系统窗口吸附（Aero Snap）；好处：拖动期间不再进 OS 模态循环，应用保持响应。
    **只在 Win10 启用**（见 _needs_throttle）：Win11 没这个毛病，用原生拖动更好。
    GLASS_DRAG_HZ 可调；GLASS_DRAG=system 可退回系统拖动。
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._win = None
        self._hwnd = 0
        self._throttle = False
        self._origin = None      # (窗体x, 窗体y, 光标x, 光标y) 物理像素
        self._RECT = self._POINT = None
        self._timer = QTimer(self)
        self._timer.setInterval(max(8, int(1000 / DRAG_HZ)))
        self._timer.timeout.connect(self._tick)

    def attach(self, win, throttle):
        self._win = win
        self._hwnd = int(win.winId())
        self._throttle = throttle
        _log("[glass] 拖动模式：%s"
             % ("节流跟随 %dHz（保 Acrylic）" % DRAG_HZ if throttle
                else "系统 startSystemMove（非穿透模式或 GLASS_DRAG=system）"))

    @Slot()
    def start(self):
        if not self._throttle or self._win is None:
            self._win.startSystemMove()
            return

        class RECT(ctypes.Structure):
            _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                        ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

        class POINT(ctypes.Structure):
            _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]

        self._RECT, self._POINT = RECT, POINT
        r, pt = RECT(), POINT()
        ctypes.windll.user32.GetWindowRect(self._hwnd, ctypes.byref(r))
        ctypes.windll.user32.GetCursorPos(ctypes.byref(pt))
        self._origin = (r.left, r.top, pt.x, pt.y)
        self._timer.start()

    def _tick(self):
        user32 = ctypes.windll.user32
        if not (user32.GetAsyncKeyState(VK_LBUTTON) & 0x8000):
            self._timer.stop()
            return
        pt = self._POINT()
        user32.GetCursorPos(ctypes.byref(pt))
        ox, oy, cx, cy = self._origin
        dpr = self._win.devicePixelRatio() or 1.0
        # 光标/窗口矩形都是物理像素，setPosition 要逻辑坐标
        self._win.setPosition(round((ox + pt.x - cx) / dpr),
                              round((oy + pt.y - cy) / dpr))

    @Slot()
    def stop(self):
        """QML 松开鼠标时调用。

        ⚠️ 不能只靠 GetAsyncKeyState 判松手：它一旦失灵，窗口会**永远跟着光标走**。
        QML 的 MouseArea 在按下时隐式抓取鼠标，onReleased 是可靠的第二道保险。
        """
        self._timer.stop()


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


def _app_base():
    """数据目录：源码运行=项目根；打包后=exe 所在目录"""
    return os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) \
        else os.path.dirname(os.path.abspath(__file__))


def main():
    qInstallMessageHandler(_qt_message)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("班级激励助手")
    app.setOrganizationName("ClassReward")

    base = _app_base()

    # 注册内置 MiSans 字体（成功则全局用它；失败回退微软雅黑）
    family = _load_fonts(base)
    app.setFont(QFont(family or 'Microsoft YaHei', 13))

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
    # QML 按它决定：桌面穿透模式（背景交给 DWM）还是自绘底
    engine.rootContext().setContextProperty("systemGlass", SYSTEM_GLASS_OK)
    # QML 按它决定：改窗口几何的操作（拖动 / 拉边缩放）要不要节流 —— 只有 Win10 需要。
    # GLASS_DRAG=system 同时关掉两者（都退回原生的逐事件行为，便于 A/B）。
    engine.rootContext().setContextProperty(
        "glassThrottle",
        SYSTEM_GLASS_OK and _needs_throttle() and os.environ.get("GLASS_DRAG") != "system")
    engine.load(QUrl.fromLocalFile(os.path.join(base, 'qml', 'Main.qml')))
    roots = engine.rootObjects()
    if not roots:
        _log('[glass] QML 加载失败')
        sys.exit(1)

    # 最小化过渡：窗口本身透明（layered），系统的最小化动画对它不生效 → 自己播一段。
    # 与是否桌面穿透无关，两种模式都要装。
    minimize_anim.attach(roots[0], app)

    # 按系统版本适配：Win10 才节流（保 Acrylic 且跟手）；Win11 用原生拖动（保 Snap/贴边）。
    # GLASS_DRAG=system 可在 Win10 上强制退回原生拖动做 A/B。
    glass_drag.attach(roots[0],
                      SYSTEM_GLASS_OK and _needs_throttle()
                      and os.environ.get("GLASS_DRAG") != "system")

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

    sys.exit(app.exec())


if __name__ == '__main__':
    main()
