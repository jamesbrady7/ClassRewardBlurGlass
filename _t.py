import sys, os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl
app = QGuiApplication([])
engine = QQmlApplicationEngine()
errs = []
engine.warnings.connect(lambda w: errs.append(str(w)))
engine.loadData(b'import QtQuick\nItem {\n  width: 200; height: 60\n  LinearGradient {\n    anchors.fill: parent\n    start: Qt.point(0, 0)\n    end: Qt.point(0, 60)\n    GradientStop { position: 0.0; color: "#660fa88f" }\n    GradientStop { position: 1.0; color: "#000fa88f" }\n  }\n}\n', QUrl('mem://t.qml'))
ok = len(engine.rootObjects()) > 0
print('LOADED' if ok else 'FAILED', len(errs))
for e in errs[:5]:
    print('ERR:', e)
