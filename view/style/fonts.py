# ============================================================
# 文件功能：内置字体加载——把 assets/fonts 下的 MiSans 注册进 Qt
# 对应Tab：全部（main.py 启动时调用一次）
# 依赖库：PyQt5, os, sys
#
# 为什么不装进 Windows 字体库？
#   用 QFontDatabase.addApplicationFont() 按应用加载，免管理员权限、
#   免污染系统字体、随程序一起发布，任何机器都能保证字体一致。
# ============================================================
import os
import sys

from PyQt5.QtGui import QFontDatabase

_WEIGHTS = ('Regular', 'Medium', 'Semibold', 'Bold')


def _font_dir():
    """定位 assets/fonts：源码运行时=项目根/assets/fonts；打包后=exe目录/assets/fonts"""
    if getattr(sys, 'frozen', False):
        base = os.path.dirname(sys.executable)
    else:
        base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(base, 'assets', 'fonts')


def load_bundled_fonts():
    """注册内置 MiSans 字重。成功返回家族名（如 'MiSans'），找不到字体文件返回 None。"""
    db = QFontDatabase()
    family = None
    for w in _WEIGHTS:
        p = os.path.join(_font_dir(), f'MiSans-{w}.ttf')
        if os.path.exists(p):
            fid = db.addApplicationFont(p)
            fams = db.applicationFontFamilies(fid) if fid >= 0 else []
            if fams and family is None:
                family = fams[0]
    return family
