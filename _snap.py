# 截图验证：真实 app.exec() 运行 Main.qml（带 _demo_data.json），强转 QQuickWindow.grabWindow 逐页存 PNG。
# 用法: python _snap.py [data.json] [outdir]
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

data = sys.argv[1] if len(sys.argv) > 1 else '_demo_data.json'
out = sys.argv[2] if len(sys.argv) > 2 else '_shots2'
os.makedirs(out, exist_ok=True)

app = QGuiApplication(sys.argv)
app.setApplicationName('班级激励助手')
app.setOrganizationName('ClassReward')
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
win.setX((scr.width() - ww) // 2); win.setY(max(10, (scr.height() - wh) // 2))
win.show()

qwin = shiboken6.wrapInstance(shiboken6.getCppPointer(win)[0], QQuickWindow)

def find(prefix):
    for c in win.findChildren(QObject):
        if c.metaObject().className().startswith(prefix):
            return c
    return None

def capture(name):
    # 多泵几帧让当前页稳定呈现，再同步抓取
    t0 = __import__('time').time()
    while __import__('time').time() - t0 < 0.25:
        QTimer.singleShot(0, lambda: None)   # no-op
    img = qwin.grabWindow()
    ok = img.save(os.path.join(out, name + '.png')) if not img.isNull() else False
    print(name, 'ok' if ok else 'FAIL', img.width() if not img.isNull() else 0)

def shot(name, after):
    QTimer.singleShot(int(after * 1000), lambda: capture(name))

nav = None
def go():
    global nav
    nav = find('SideNav_QMLTYPE')
    if nav is None:
        print('nav missing'); app.quit(); return
    nav.setProperty('currentIndex', 0); shot('00_roster', 0.8)
    QTimer.singleShot(2300, s1)
def s1():
    nav.setProperty('currentIndex', 1); shot('01_groups', 0.8); QTimer.singleShot(2300, s2)
def s2():
    nav.setProperty('currentIndex', 2); QTimer.singleShot(1000, s2b)
def s2b():
    rp = find('RandomPickTab_QMLTYPE')
    try:
        rp.setProperty('stuResult', bridge.randomPickStudents(5))
        rp.setProperty('grpResult', bridge.randomPickGroups(3))
    except Exception as e:
        print('random set ERR', e)
    shot('02_random', 0.6); QTimer.singleShot(2300, s3)
def s3():
    nav.setProperty('currentIndex', 3); QTimer.singleShot(1000, s3b)
def s3b():
    bt = find('BatchTab_QMLTYPE')
    try:
        st = bridge.students
        bt.setProperty('sel', ','.join([st[0]['id'], st[3]['id']]))
    except Exception as e:
        print('batch set ERR', e)
    shot('03_batch', 0.6); QTimer.singleShot(2300, s4)
def s4():
    nav.setProperty('currentIndex', 4); shot('04_shop_all', 0.8); QTimer.singleShot(2300, s4b)
def s4b():
    sh = find('ShopTab_QMLTYPE')
    try:
        sh.setProperty('cat', '传说')
    except Exception as e:
        print('shop set ERR', e)
    shot('05_shop_legend', 0.6); QTimer.singleShot(2300, s5)
def s5():
    nav.setProperty('currentIndex', 6); shot('06_analysis_open', 0.8); QTimer.singleShot(2300, s5b)
def s5b():
    an = find('AnalysisTab_QMLTYPE')
    try:
        an.setProperty('hideName', True)
    except Exception as e:
        print('analysis ERR', e)
    shot('07_analysis_closed', 0.6); QTimer.singleShot(2300, s6)
def s6():
    print('DONE')
    app.quit()

QTimer.singleShot(1800, go)
sys.exit(app.exec())
