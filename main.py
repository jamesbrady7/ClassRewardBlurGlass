# ============================================================
# 文件功能：应用入口（PySide6 + QML）
# 对应Tab：全部
# 依赖库：PySide6, controller, model, qml_bridge, qml_theme
# 使用方法：python main.py 或 双击启动器
#
# 架构：model / controller 是纯 Python（MVC 数据层与业务层，不碰 Qt），
#       QML 是视图层，通过 qml_bridge 的 View-Model 适配器交互。
# ============================================================
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PySide6.QtGui import QGuiApplication, QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl

from controller.app_controller import AppController
from model.storage import StorageManager
from qml_bridge import RewardBridge
from qml_theme import Theme

_FONT_WEIGHTS = ('Regular', 'Medium', 'Semibold', 'Bold')


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
    engine.rootContext().setContextProperty("reward", bridge)
    engine.rootContext().setContextProperty("Theme", theme)
    engine.load(QUrl.fromLocalFile(os.path.join(base, 'qml', 'Main.qml')))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
