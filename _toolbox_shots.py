# 工具箱截图：入口列表 / 倒计时工具（昼夜）/ 秒表工具 / 悬浮球倒计时卡
import os
import sys
sys.path.insert(0, os.getcwd())
sys.stdout.reconfigure(encoding='utf-8')
import shiboken6
from PySide6.QtCore import QObject, QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication, QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickWindow

from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

MSGS = []
qInstallMessageHandler(lambda mode, ctx, msg: MSGS.append(msg))

BASE = os.getcwd()
app = QGuiApplication(sys.argv)
app.setApplicationName('班级激励助手')
app.setOrganizationName('ClassReward')
fd = os.path.join(BASE, 'assets', 'fonts')
for w in ('Regular', 'Medium', 'Semibold', 'Bold'):
    p = os.path.join(fd, 'MiSans-%s.ttf' % w)
    if os.path.exists(p):
        fid = QFontDatabase.addApplicationFont(p)
        fams = QFontDatabase.applicationFontFamilies(fid) if fid >= 0 else []
        if fams:
            app.setFont(QFont(fams[0], 13))
            break

engine = QQmlApplicationEngine()
theme = Theme()
bridge = RewardBridge(AppController(StorageManager(os.path.join(BASE, '_demo_data.json'))))
engine.rootContext().setContextProperty('reward', bridge)
engine.rootContext().setContextProperty('Theme', theme)
engine.rootContext().setContextProperty('systemGlass', False)
engine.rootContext().setContextProperty('glassThrottle', False)
engine.rootContext().setContextProperty('floatNoActivateCtx', True)
from float_window import FloatPrefs, _FloatBridge
_prefs = FloatPrefs()
_fb = _FloatBridge(None)
engine.rootContext().setContextProperty('floatPrefs', _prefs)
engine.rootContext().setContextProperty('floatBridge', _fb)

engine.load(QUrl.fromLocalFile(os.path.join(BASE, 'qml', 'Main.qml')))
win = engine.rootObjects()[0]
win.setProperty('width', int(os.environ.get('SHOT_W', '1500')))
win.setProperty('height', int(os.environ.get('SHOT_H', '930')))
win.show()
qwin = shiboken6.wrapInstance(shiboken6.getCppPointer(win)[0], QQuickWindow)
hub = win.property('timerHub')
fwin = None
toolbox = None
for c in win.findChildren(QObject):
    if c.metaObject().className().startswith('ToolboxTab'):
        toolbox = c
        break

def save(target, path):
    q = shiboken6.wrapInstance(shiboken6.getCppPointer(target)[0], QQuickWindow)
    img = q.grabWindow()
    print('save', path, img.save(path), img.width(), 'x', img.height(), flush=True)

def expr(obj, code):
    e = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    v, _ = e.evaluate()
    if e.hasError():
        print('EXPR ERROR', code, e.error().toString(), flush=True)
    return v

def step1():
    for c in win.findChildren(QObject):
        if c.metaObject().className().startswith('SideNav_QMLTYPE'):
            c.setProperty('currentIndex', 7)
    # 让入口卡带着"计时中"状态出现
    expr(win, 'timerHub.startTimer()')
    QTimer.singleShot(1200, step2)

def step2():
    save(win, '_shot_toolbox_list_day.png')
    toolbox.setProperty('activeTool', 'countdown')
    QTimer.singleShot(700, step3)

def step3():
    save(win, '_shot_toolbox_countdown_day.png')
    toolbox.setProperty('activeTool', 'stopwatch')
    QTimer.singleShot(600, step4)

def step4():
    save(win, '_shot_toolbox_stopwatch_day.png')
    theme.night = True
    QTimer.singleShot(900, step5)

def step5():
    save(win, '_shot_toolbox_stopwatch_night.png')
    toolbox.setProperty('activeTool', 'countdown')
    QTimer.singleShot(600, step6)

def step6():
    save(win, '_shot_toolbox_countdown_night.png')
    toolbox.setProperty('activeTool', '')
    QTimer.singleShot(400, step7)

def step7():
    save(win, '_shot_toolbox_list_night.png')
    win.hide()
    engine.rootContext().setContextProperty('timerHub', hub)
    engine.load(QUrl.fromLocalFile(os.path.join(BASE, 'qml', 'float', 'FloatBall.qml')))
    global fwin
    fwin = engine.rootObjects()[-1]
    fwin.show()
    QTimer.singleShot(800, step8)

def step8():
    hub.setProperty('timerTab', 0)
    fwin.setProperty('mode', 6)
    QTimer.singleShot(1400, step9)

def step9():
    save(fwin, '_shot_float_timer.png')
    print('float timerRunning=', expr(fwin, 'timerHub.timerRunning'),
          'left=', expr(fwin, 'timerHub.timerLeft'), flush=True)
    errs = [m for m in MSGS if 'Error' in m or 'unavailable' in m or 'Cannot' in m]
    print('QML ERRORS:', len(errs), flush=True)
    for m in errs[:10]:
        print(' ', m, flush=True)
    try:
        win.setProperty('forceClose', True)
        win.close()
    except Exception:
        pass
    app.quit()
    os._exit(0)

QTimer.singleShot(30000, lambda: (print('WATCHDOG', flush=True), os._exit(4)))
QTimer.singleShot(1500, step1)
sys.exit(app.exec())
