import sys, os
sys.path.insert(0, os.getcwd())
from PySide6.QtGui import QGuiApplication, QPixmap, QPainter, QColor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl, QObject
app = QGuiApplication([])
from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

sm = StorageManager(os.path.join(os.getcwd(), 'class_reward_data.json'))
ctrl = AppController(sm)
bridge = RewardBridge(ctrl)
engine = QQmlApplicationEngine()
theme = Theme()
engine.rootContext().setContextProperty("reward", bridge)
engine.rootContext().setContextProperty("Theme", theme)
engine.load(QUrl.fromLocalFile(os.path.join(os.getcwd(), 'qml', 'Main.qml')))
for _ in range(10): app.processEvents()

def find_by_class(obj, prefix):
    for c in obj.findChildren(QObject):
        if c.metaObject().className().startswith(prefix):
            return c
    return None

roster = find_by_class(engine.rootObjects()[0], "RosterTab_QMLTYPE")
print("RosterTab size:", roster.property("width"), "x", roster.property("height"))
print("RosterTab visible:", roster.property("visible"), "opacity:", roster.property("opacity"))
pm = QPixmap(int(roster.property("width")), int(roster.property("height")))
pm.fill(QColor('#e4eaf2'))
p = QPainter(pm)
roster.metaObject().invokeMethod(roster, "grab")  # 触发绘制
roster.render(p)  # QQuickItem::render 需要 QQuickWindow
p.end()
# render 对 QQuickItem 用 grabToImage 更可靠，这里直接读窗口
win = roster.metaObject().className()
img = pm.toImage()
def probe(x, y):
    c = img.pixelColor(x, y)
    return "RGB(%d,%d,%d)" % (c.red(), c.green(), c.blue())
print("probe(500, 80):", probe(500, 80))
print("probe(500, 300):", probe(500, 300))
