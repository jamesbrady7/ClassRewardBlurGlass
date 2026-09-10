# 单页截图验证：只切到小组排行榜、截一张、退出（控制请求体积用）
# 用法: python _podium_shot.py [data.json] [out.png]
import sys, os, time
sys.path.insert(0, os.getcwd())
import shiboken6
from PySide6.QtGui import QGuiApplication, QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtCore import QUrl, QObject, QTimer
from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

data = sys.argv[1] if len(sys.argv) > 1 else '_demo_data.json'
out = sys.argv[2] if len(sys.argv) > 2 else '_podium_shot.png'

app = QGuiApplication(sys.argv)
app.setApplicationName('班级激励助手')
fd = os.path.join(os.getcwd(), 'assets', 'fonts')
if os.path.isdir(fd):
    for w in ('Regular', 'Medium', 'Semibold', 'Bold'):
        p = os.path.join(fd, 'MiSans-%s.ttf' % w)
        if os.path.exists(p):
            fid = QFontDatabase.addApplicationFont(p)
            fams = QFontDatabase.applicationFontFamilies(fid) if fid >= 0 else []
            if fams:
                app.setFont(QFont(fams[0], 13)); break

sm = StorageManager(os.path.join(os.getcwd(), data))
ctrl = AppController(sm)
bridge = RewardBridge(ctrl)
engine = QQmlApplicationEngine()
theme = Theme()
engine.rootContext().setContextProperty('reward', bridge)
engine.rootContext().setContextProperty('Theme', theme)
engine.load(QUrl.fromLocalFile(os.path.join(os.getcwd(), 'qml', 'Main.qml')))
win = engine.rootObjects()[0]
if not win:
    print('LOAD FAIL'); sys.exit(1)

scr = app.primaryScreen().geometry()
ww = min(1500, scr.width() - 80); wh = min(930, scr.height() - 140)
win.setWidth(ww); win.setHeight(wh)
win.show()

qwin = shiboken6.wrapInstance(shiboken6.getCppPointer(win)[0], QQuickWindow)

def find(prefix):
    for c in win.findChildren(QObject):
        if c.metaObject().className().startswith(prefix):
            return c
    return None

def go():
    nav = find('SideNav_QMLTYPE')
    if nav is None:
        print('nav missing'); app.quit(); return
    nav.setProperty('currentIndex', 1)
    QTimer.singleShot(2600, cap)   # 等错峰弹升动画播完

def cap():
    img = qwin.grabWindow()
    if img.isNull():
        print('GRAB FAIL'); app.quit(); return
    # 只裁剪领奖台面板区域太大？直接存整窗（一张）
    ok = img.save(out)
    print('saved', out, ok, img.width(), 'x', img.height())
    app.quit()

QTimer.singleShot(1800, go)
sys.exit(app.exec())
