# 课堂快捷悬浮球 —— 独立测试版（不改主程序）
#
# 跑法：  python _float_test.py
#   · 若点击没反应（极少数机器上 NOACTIVATE 会吞触摸），改用：
#         FLOAT_NOACTIVATE=0 python _float_test.py
#
# 它复用主程序的数据层（class_reward_data.json），所以加分是**真加分**、
# 主程序里也能看到；测试期请留意（有"撤回"可回退）。
import os
import sys
import ctypes

sys.path.insert(0, os.getcwd())

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication, QFont, QImage
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow, QQuickImageProvider

# 透明窗口必须在创建任何 QQuickWindow 之前打开 alpha
QQuickWindow.setDefaultAlphaBuffer(True)

from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

BASE = os.path.dirname(os.path.abspath(__file__))


class Backdrop(QQuickImageProvider):
    """毛玻璃的模糊源：Python 定期抓"窗口背后"的屏幕，QML 端取来模糊。"""

    def __init__(self):
        super().__init__(QQuickImageProvider.Image)
        self.img = QImage()

    def requestImage(self, iid, size, requestedSize):
        return self.img


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("课堂悬浮球（测试版）")
    app.setQuitOnLastWindowClosed(True)

    # 与主程序同字体（失败就用系统字体，不影响使用）
    try:
        from main import _load_fonts
        fam = _load_fonts(BASE)
        app.setFont(QFont(fam or 'Microsoft YaHei', 13))
    except Exception:
        pass

    data_file = os.environ.get('FLOAT_DATA', 'class_reward_data.json')
    storage = StorageManager(os.path.join(BASE, data_file))
    ctrl = AppController(storage)
    bridge = RewardBridge(ctrl)
    theme = Theme()          # 必须持引用，否则被 GC、QML 端读到 null

    engine = QQmlApplicationEngine()
    provider = Backdrop()
    engine.addImageProvider("floatbackdrop", provider)
    engine.rootContext().setContextProperty("reward", bridge)
    engine.rootContext().setContextProperty("Theme", theme)
    engine.rootContext().setContextProperty("systemGlass", False)
    engine.load(QUrl.fromLocalFile(os.path.join(BASE, 'qml', 'float', 'FloatBall.qml')))

    roots = engine.rootObjects()
    if not roots:
        print("[float] QML 加载失败")
        sys.exit(1)
    win = roots[0]
    win.setProperty("floatNoActivate", os.environ.get('FLOAT_NOACTIVATE', '1') != '0')

    # 把自己排除在抓屏之外：否则毛玻璃会抓到自己 → 反馈回路（越糊越花）
    # 自检时（FLOAT_CAPTURABLE=1）跳过，方便用真实截屏核对渲染
    if os.environ.get('FLOAT_CAPTURABLE') != '1':
        try:
            hwnd = int(win.winId())
            ctypes.windll.user32.SetWindowDisplayAffinity(hwnd, 0x11)   # WDA_EXCLUDEFROMCAPTURE
        except Exception as e:
            print("[float] 抓图排除失败：%r" % (e,))

    def grab():
        try:
            if not win.isVisible():
                return
            # 自检时可抓旁边的区域（避免拍到本窗口自己形成反馈回路）
            dx = int(os.environ.get('FLOAT_CAPTURE_OFFSET', '0'))
            g = win.screen().grabWindow(0, int(win.x()) - dx, int(win.y()),
                                        int(win.width()), int(win.height()))
            if g.isNull():
                return
            provider.img = g.toImage()
            win.setProperty("backdropVersion",
                            int(win.property("backdropVersion") or 0) + 1)
        except Exception:
            pass

    timer = QTimer()
    timer.timeout.connect(grab)
    timer.start(260)

    # ⚠️ 窗口尺寸一变就**立刻重抓**：
    #    否则旧的小尺寸截图会被 PreserveAspectCrop 拉伸铺满新窗口
    #    （表现为切换形态时出现一个巨大的白色模糊圆球）
    def regrab():
        provider.img = QImage()      # 先清空，避免旧图被拉伸
        grab()

    for sig in ('widthChanged', 'heightChanged'):
        try:
            getattr(win, sig).connect(regrab)
        except Exception:
            pass

    # 自检模式：FLOAT_SHOTS=<目录> 时依次切形态、存图、退出（开发用）
    shot_dir = os.environ.get('FLOAT_SHOTS')
    if shot_dir:
        seq = ['ball', 'menu', 'batch', 'pick', 'settings', 'confirm']
        idx = {'i': -1}

        def shoot_step():
            i = idx['i']
            if i >= 0:
                win.grabWindow().save(os.path.join(shot_dir, '_fb_%02d_%s.png' % (i, seq[i])))
                if os.environ.get('FLOAT_CAPTURABLE') == '1':
                    scr = app.primaryScreen().grabWindow(
                        0, int(win.x()), int(win.y()), int(win.width()), int(win.height()))
                    scr.save(os.path.join(shot_dir, '_fb_%02d_%s_screen.png' % (i, seq[i])))
            idx['i'] = i + 1
            if idx['i'] >= len(seq):
                app.quit()
                return
            m = idx['i']
            if m == 2:      # 批量：预选 3 个学生 + 一个分类，看选中态
                st = bridge.students
                win.setProperty("selStudents", [x["id"] for x in st[:3]])
                win.setProperty("cat", "课堂")
            if m == 3:      # 抽取：预填两个结果，看大字排版
                st = bridge.students
                win.setProperty("picked", st[:2])
            win.setProperty("mode", m)

        t2 = QTimer()
        t2.timeout.connect(shoot_step)
        t2.start(650)

    sys.exit(app.exec())


if __name__ == '__main__':
    main()
