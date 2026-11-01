# 验证：工具箱入口列表 → 进入工具；并与悬浮球共用同一个 TimerHub。
# 真实鼠标点击 + 跨 QML 根对象读取。
import os
import sys
import traceback
import functools
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.getcwd())
import shiboken6
from PySide6.QtCore import QObject, QPoint, QPointF, Qt, QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication, QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest

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
win.setProperty('width', 1500)
win.setProperty('height', 930)
win.show()
qwin = shiboken6.wrapInstance(shiboken6.getCppPointer(win)[0], QQuickWindow)
hub = win.property('timerHub')
fwin = None
print('hub:', hub.metaObject().className() if hub is not None else None)

results = []
def check(name, ok, detail=''):
    results.append((name, bool(ok), detail))
    print(('PASS ' if ok else 'FAIL ') + name + ('  ' + detail if detail else ''), flush=True)

def qitem(o):
    return shiboken6.wrapInstance(shiboken6.getCppPointer(o)[0], QQuickItem)

def all_items(root=None):
    """遍历窗口的视觉树（Repeater 代理不在 QObject children 上，但一定在 childItems 里）。"""
    start = root if root is not None else qwin.contentItem()
    yield start
    for ch in start.childItems():
        yield from all_items(ch)

def click_text(label):
    """找到 CuteButton(文本=label) 并真实点击。"""
    found = []
    for it in all_items():
        if not it.metaObject().className().startswith('CuteButton_QMLTYPE'):
            continue
        if it.property('text') != label or not it.isVisible():
            continue
        found.append(it.mapToScene(QPointF(it.width() / 2, it.height() / 2)))
    print('  buttons', label, [(round(p.x()), round(p.y())) for p in found], flush=True)
    if not found:
        return False
    pt = found[0]
    QTest.mouseClick(qwin, Qt.LeftButton, Qt.NoModifier, QPoint(int(pt.x()), int(pt.y())))
    return True

def click_label(label):
    """点击可见 Text 的中心（工具箱入口卡）。"""
    for it in all_items():
        if it.metaObject().className().startswith('QQuickText')                 and it.property('text') == label and it.isVisible():
            pt = it.mapToScene(QPointF(it.width() / 2, it.height() / 2))
            print('  text', label, (round(pt.x()), round(pt.y())), flush=True)
            QTest.mouseClick(qwin, Qt.LeftButton, Qt.NoModifier,
                             QPoint(int(pt.x()), int(pt.y())))
            return True
    return False

def find_text(text):
    for it in all_items():
        if it.property('text') == text:
            return True
    return False

def expr(obj, code):
    e = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    val, _ = e.evaluate()
    if e.hasError():
        print('  EXPR ERROR', code, '->', e.error().toString(), flush=True)
    return val

# ── 主界面：工具箱入口 → 倒计时工具 → 开始 ──
def step1():
    for c in win.findChildren(QObject):
        if c.metaObject().className().startswith('SideNav_QMLTYPE'):
            c.setProperty('currentIndex', 7)
    QTimer.singleShot(900, step2)

def step2():
    print('--- 工具箱列表：点「倒计时」入口 ---', flush=True)
    check('列表里出现倒计时入口', find_text('倒计时'))
    check('列表里出现秒表入口', find_text('秒表'))
    check('列表里出现当前值 00:05:00', find_text('00:05:00'))
    ok = click_label('倒计时')
    check('点击倒计时入口', ok)
    QTimer.singleShot(650, step3)

def step3():
    print('--- 倒计时工具页：点「开始」 ---', flush=True)
    check('工具页出现「‹ 工具箱」返回按钮', find_text('‹ 工具箱'))
    ok = click_text('开始')
    check('找到并点击倒计时开始按钮', ok)
    QTimer.singleShot(350, step4)

def step4():
    check('点击后 timerRunning=True', hub.property('timerRunning') is True,
          repr(hub.property('timerRunning')))
    check('开始后剩余 ≈ 总长', abs(hub.property('timerLeft') - hub.property('timerTotal')) < 1500,
          'left=%s total=%s' % (hub.property('timerLeft'), hub.property('timerTotal')))
    QTimer.singleShot(1200, step5)

# ── 进悬浮球：同一实例 ──
def step5():
    t1 = hub.property('timerLeft')
    check('1.2s 后倒计时在走', t1 < hub.property('timerTotal') - 800, 'left=%s' % t1)
    win.hide()
    engine.rootContext().setContextProperty('timerHub', hub)
    engine.load(QUrl.fromLocalFile(os.path.join(BASE, 'qml', 'float', 'FloatBall.qml')))
    roots = engine.rootObjects()
    check('悬浮球 QML 已加载', len(roots) > 1, 'roots=%d' % len(roots))
    global fwin
    fwin = roots[-1]
    fwin.show()
    QTimer.singleShot(700, step6)

def step6():
    fhub = expr(fwin, 'timerHub')
    same = fhub is not None and shiboken6.getCppPointer(fhub)[0] == shiboken6.getCppPointer(hub)[0]
    check('悬浮球拿到的是同一个 timerHub 对象', same)
    check('悬浮球看到倒计时在运行', expr(fwin, 'timerHub.timerRunning') is True,
          repr(expr(fwin, 'timerHub.timerRunning')))
    a = hub.property('timerLeft')
    b = expr(fwin, 'timerHub.timerLeft')
    check('两边的剩余时间一致', b is not None and abs(a - b) < 1, 'main=%s float=%s' % (a, b))
    QTimer.singleShot(1100, step7)

def step7():
    a = hub.property('timerLeft')
    check('切进悬浮球后倒计时继续走', a < hub.property('timerTotal') - 1800, 'left=%s' % a)
    expr(fwin, 'timerHub.timerTab = 1')
    expr(fwin, 'timerHub.swToggle()')
    QTimer.singleShot(800, step8)

def step8():
    check('悬浮球里秒表在走', hub.property('swRunning') is True,
          'elapsed=%s' % hub.property('swElapsed'))
    check('秒表时间 > 0.5s', hub.property('swElapsed') > 500,
          'elapsed=%s' % hub.property('swElapsed'))
    check('切页状态共享 timerTab=1', hub.property('timerTab') == 1,
          repr(hub.property('timerTab')))
    print('  float fmtSw =', expr(fwin, 'timerHub.fmtSw(timerHub.swElapsed)'), flush=True)
    fwin.hide()
    win.show()
    QTimer.singleShot(500, step9)

# ── 回主界面：同一实例；暂停；返回列表看实时值 ──
def step9():
    check('回到主界面后倒计时仍在运行', hub.property('timerRunning') is True)
    check('回到主界面后秒表仍在走', hub.property('swRunning') is True,
          'elapsed=%s' % hub.property('swElapsed'))
    ok = click_text('暂停')
    check('找到主界面的「暂停」', ok)
    QTimer.singleShot(300, step10)

def step10():
    check('主界面暂停后计时停止', hub.property('timerRunning') is False,
          repr(hub.property('timerRunning')))
    ok = click_text('‹ 工具箱')
    check('工具页点「‹ 工具箱」返回列表', ok)
    QTimer.singleShot(600, step11)

def step11():
    want = '%02d:%02d:%02d' % (hub.property('dispH'), hub.property('dispM'),
                               hub.property('dispS'))
    check('入口卡显示当前倒计时值 ' + str(want), find_text(want))
    finish()

def finish():
    if results:
        bad = [r for r in results if not r[1]]
        print('\n==== %d/%d PASS ====' % (len(results) - len(bad), len(results)), flush=True)
        if bad:
            print('FAILED:', [r[0] for r in bad], flush=True)
    errs = [m for m in MSGS if 'Error' in m or 'unavailable' in m or 'Cannot' in m]
    print('QML ERRORS:', len(errs), flush=True)
    for m in errs[:20]:
        print('  ', m, flush=True)
    try:
        win.setProperty('forceClose', True)
        win.close()
    except Exception:
        pass
    app.quit()
    os._exit(0)

def safe(fn):
    @functools.wraps(fn)
    def w(*a):
        print('>> ' + fn.__name__, flush=True)
        try:
            fn(*a)
        except Exception:
            traceback.print_exc()
            finish()
    return w

step1, step2, step3, step4, step5 = map(safe, [step1, step2, step3, step4, step5])
step6, step7, step8, step9, step10, step11 = map(
    safe, [step6, step7, step8, step9, step10, step11])

QTimer.singleShot(30000, lambda: (print('WATCHDOG timeout', flush=True), os._exit(4)))
QTimer.singleShot(1800, step1)
sys.exit(app.exec())
