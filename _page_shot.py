# 通用单页截图：python _page_shot.py <tab索引0-6> <数据json> <输出png>
# 只切到目标页、截 1 张全窗 PNG 就退出（控制上下文体积）
import sys, os
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

tab = int(sys.argv[1]) if len(sys.argv) > 1 else 0
data = sys.argv[2] if len(sys.argv) > 2 else '_demo_data.json'
out = sys.argv[3] if len(sys.argv) > 3 else '_page_shot.png'
delay = float(sys.argv[4]) if len(sys.argv) > 4 else 0.6

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
    nav.setProperty('currentIndex', tab)
    import os
    ps = os.environ.get('PAGE_SET', '')
    if ps:
        cls, _, prop = ps.partition('.')
        if cls and prop:
            t = find(cls + '_QMLTYPE')
            if t:
                name, _, val = prop.partition('=')
                try:
                    t.setProperty(name, int(val) if val.lstrip('-').isdigit() else val)
                except Exception as e:
                    print('set err', e)
    QTimer.singleShot(int(delay * 1000), cap)

def cap():
    img = qwin.grabWindow()
    ok = img.save(out)
    print('saved', out, ok, img.width(), 'x', img.height())
    app.quit()

QTimer.singleShot(1800, go)
sys.exit(app.exec())
