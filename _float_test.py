# 课堂快捷悬浮球 —— 独立测试版（不改主程序）
#
# 跑法：  python _float_test.py
#   · 若点击没反应（极少数机器上"不抢焦点"会吞触摸），改用：
#         FLOAT_NOACTIVATE=0 python _float_test.py
#
# 毛玻璃实现：**Python 抓"窗口背后的桌面" → 模糊 → 圆角/圆形遮罩 → 白色 tint，烘成一张 RGBA 图**，
#   QML 只贴图。
#   为什么不用系统 Acrylic（主程序用的那套）：实测它在这个悬浮窗上**不认窗口遮罩**，
#   会把整个矩形都糊上 —— 球是圆的，圆外糊成方块很难看。
#   为什么不卡：抓屏（BitBlt，实测 ~17ms）放在**后台线程**，不占 UI 线程；
#   动画期间元素位置固定（只做缩放/淡入），所以没有"每帧重烘焙"。
import os
import sys
import time
import ctypes
import threading
from ctypes import wintypes

sys.path.insert(0, os.getcwd())

from PySide6.QtCore import QTimer, QUrl, Qt, QRectF
from PySide6.QtGui import (QGuiApplication, QFont, QImage, QPainter, QColor,
                           QPainterPath, QRegion, QSurfaceFormat)
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow, QQuickImageProvider

QQuickWindow.setDefaultAlphaBuffer(True)
_fmt = QSurfaceFormat()
_fmt.setAlphaBufferSize(8)
QSurfaceFormat.setDefaultFormat(_fmt)

from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

BASE = os.path.dirname(os.path.abspath(__file__))

# 与 FloatBall.qml 保持一致
BALL_OFF = (140, 150)
BALL_SIZE = 100
BUBBLE_OFFS = [(-74, 74), (-105, 0), (-74, -74), (0, -105)]
BUBBLE_SIZE = 68

# ══════════════════════════════════════════════════════════════
#  快速抓屏（BitBlt，~17ms；放后台线程跑）
# ══════════════════════════════════════════════════════════════
_u, _g = ctypes.windll.user32, ctypes.windll.gdi32
_u.GetDC.restype = wintypes.HDC
_u.GetDC.argtypes = [wintypes.HWND]
_g.CreateCompatibleDC.restype = wintypes.HDC
_g.CreateCompatibleDC.argtypes = [wintypes.HDC]
_g.CreateCompatibleBitmap.restype = wintypes.HBITMAP
_g.CreateCompatibleBitmap.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int]
_g.SelectObject.restype = wintypes.HGDIOBJ
_g.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
_g.BitBlt.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                      wintypes.HDC, ctypes.c_int, ctypes.c_int, wintypes.DWORD]
_g.GetDIBits.argtypes = [wintypes.HDC, wintypes.HBITMAP, wintypes.UINT, wintypes.UINT,
                         ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT]
_g.DeleteObject.argtypes = [wintypes.HGDIOBJ]
_g.DeleteDC.argtypes = [wintypes.HDC]
_u.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]


class _BIH(ctypes.Structure):
    _fields_ = [('biSize', wintypes.DWORD), ('biWidth', wintypes.LONG), ('biHeight', wintypes.LONG),
                ('biPlanes', wintypes.WORD), ('biBitCount', wintypes.WORD),
                ('biCompression', wintypes.DWORD), ('biSizeImage', wintypes.DWORD),
                ('biXPelsPerMeter', wintypes.LONG), ('biYPelsPerMeter', wintypes.LONG),
                ('biClrUsed', wintypes.DWORD), ('biClrImportant', wintypes.DWORD)]


def fast_grab(x, y, w, h):
    hdc = _u.GetDC(0)
    mem = _g.CreateCompatibleDC(hdc)
    hb = _g.CreateCompatibleBitmap(hdc, w, h)
    old = _g.SelectObject(mem, hb)
    _g.BitBlt(mem, 0, 0, w, h, hdc, x, y, 0x00CC0020)      # SRCCOPY
    bi = _BIH()
    bi.biSize = ctypes.sizeof(_BIH)
    bi.biWidth = w
    bi.biHeight = -h          # 负 = 自上而下
    bi.biPlanes = 1
    bi.biBitCount = 32
    buf = ctypes.create_string_buffer(w * h * 4)
    _g.GetDIBits(mem, hb, 0, h, buf, ctypes.byref(bi), 0)
    _g.SelectObject(mem, old)
    _g.DeleteObject(hb)
    _g.DeleteDC(mem)
    _u.ReleaseDC(0, hdc)
    return QImage(buf, w, h, w * 4, QImage.Format_ARGB32).copy()


# ══════════════════════════════════════════════════════════════
#  Image providers
# ══════════════════════════════════════════════════════════════
class Backdrop(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQuickImageProvider.Image)
        self._lock = threading.Lock()
        self.img = QImage()

    def requestImage(self, iid, size, requestedSize):
        with self._lock:
            return self.img


class Glass(QQuickImageProvider):
    """按 URL 现场烘一块毛玻璃：裁剪 → 模糊 → 圆角遮罩 → 白色 tint。
    URL: image://floatglass/<x>_<y>_<w>_<h>_<r>_<tintA>?v=<版本>"""

    def __init__(self, backdrop):
        super().__init__(QQuickImageProvider.Image)
        self.backdrop = backdrop

    def requestImage(self, iid, size, requestedSize):
        try:
            x, y, w, h, r, ta = [int(float(v)) for v in iid.split('?')[0].split('_')]
        except Exception:
            return QImage()
        if w <= 0 or h <= 0:
            return QImage()

        with self.backdrop._lock:
            src = self.backdrop.img.copy()

        out = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
        out.fill(Qt.transparent)
        p = QPainter(out)
        p.setRenderHint(QPainter.Antialiasing)
        path = QPainterPath()
        path.addRoundedRect(QRectF(0, 0, w, h), r, r)
        p.setClipPath(path)

        if not src.isNull():
            crop = src.copy(x, y, w, h)
            if not crop.isNull():
                sw, sh = max(1, w // 4), max(1, h // 4)
                small = crop.scaled(sw, sh, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
                p.drawImage(0, 0, small.scaled(w, h, Qt.IgnoreAspectRatio, Qt.SmoothTransformation))

        p.fillRect(QRectF(0, 0, w, h), QColor(255, 255, 255, ta))
        p.end()
        return out


def _circle(cx, cy, r):
    return QRegion(int(cx - r), int(cy - r), int(2 * r), int(2 * r), QRegion.Ellipse)


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("课堂悬浮球（测试版）")
    app.setQuitOnLastWindowClosed(True)

    try:
        from main import _load_fonts
        fam = _load_fonts(BASE)
        app.setFont(QFont(fam or 'Microsoft YaHei', 13))
    except Exception:
        pass

    data_file = os.environ.get('FLOAT_DATA', 'class_reward_data.json')
    storage = StorageManager(os.path.join(BASE, data_file))
    bridge = RewardBridge(AppController(storage))
    theme = Theme()

    engine = QQmlApplicationEngine()
    backdrop = Backdrop()
    engine.addImageProvider("floatbackdrop", backdrop)
    engine.addImageProvider("floatglass", Glass(backdrop))
    engine.rootContext().setContextProperty("reward", bridge)
    engine.rootContext().setContextProperty("Theme", theme)
    engine.rootContext().setContextProperty("systemGlass", False)
    engine.rootContext().setContextProperty(
        "floatNoActivateCtx", os.environ.get('FLOAT_NOACTIVATE', '1') != '0')
    engine.load(QUrl.fromLocalFile(os.path.join(BASE, 'qml', 'float', 'FloatBall.qml')))

    roots = engine.rootObjects()
    if not roots:
        print("[float] QML 加载失败")
        sys.exit(1)
    win = roots[0]

    # 任务栏/ALT+TAB 隐藏（默认关；需要时 FLOAT_TOOLWINDOW=1）
    if os.environ.get('FLOAT_TOOLWINDOW') == '1':
        try:
            hwnd = int(win.winId())
            u = ctypes.windll.user32
            u.GetWindowLongPtrW.restype = ctypes.c_longlong
            u.SetWindowLongPtrW.restype = ctypes.c_longlong
            u.SetWindowLongPtrW(hwnd, -20, u.GetWindowLongPtrW(hwnd, -20) | 0x00000080)
        except Exception as e:
            print("[float] 隐藏任务栏图标失败：%r" % (e,))

    # ── 窗口遮罩：形状之外**点击穿透**（不挡 PPT）──
    def apply_mask(*_):
        try:
            mode = int(win.property("mode") or 0)
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
        except Exception as e:
            print("[float] mask 失败：%r" % (e,))

    apply_mask()
    try:
        win.maskVersionChanged.connect(apply_mask)
        win.widthChanged.connect(apply_mask)
        win.heightChanged.connect(apply_mask)
    except Exception:
        pass

    # ── 后台线程抓屏（不占 UI 线程 → 动画不卡）──
    target = {'rect': (int(win.x()), int(win.y()), int(win.width()), int(win.height()))}
    stop = threading.Event()

    def capture_loop():
        while not stop.is_set():
            x, y, w, h = target['rect']
            try:
                if w > 2 and h > 2:
                    img = fast_grab(x, y, w, h)
                    with backdrop._lock:
                        backdrop.img = img
            except Exception:
                pass
            time.sleep(0.10)

    threading.Thread(target=capture_loop, daemon=True).start()

    # GUI 线程：只更新抓图目标 + 触发贴图刷新（裁+模糊在 provider 里做）
    def tick():
        target['rect'] = (int(win.x()), int(win.y()), int(win.width()), int(win.height()))
        win.setProperty("backdropVersion", int(win.property("backdropVersion") or 0) + 1)

    t = QTimer()
    t.timeout.connect(tick)
    t.start(100)

    # 自检模式
    shot_dir = os.environ.get('FLOAT_SHOTS')
    if shot_dir:
        seq = ['ball', 'menu', 'batch', 'pick', 'settings', 'confirm']
        idx = {'i': -1}

        def shoot_step():
            i = idx['i']
            if i >= 0:
                win.grabWindow().save(os.path.join(shot_dir, '_fb_%02d_%s.png' % (i, seq[i])))
                scr = app.primaryScreen().grabWindow(
                    0, int(win.x()), int(win.y()), int(win.width()), int(win.height()))
                scr.save(os.path.join(shot_dir, '_fb_%02d_%s_screen.png' % (i, seq[i])))
            idx['i'] = i + 1
            if idx['i'] >= len(seq):
                app.quit()
                return
            m = idx['i']
            if m == 2:
                st = bridge.students
                win.setProperty("selStudents", [x["id"] for x in st[:3]])
                win.setProperty("cat", "课堂")
            if m == 3:
                win.setProperty("picked", bridge.students[:2])
            win.setProperty("mode", m)

        t2 = QTimer()
        t2.timeout.connect(shoot_step)
        t2.start(700)

    sys.exit(app.exec())


if __name__ == '__main__':
    main()
