# ============================================================
# 文件功能：轻量动效工具——窗口入场淡入、小控件淡入
# 对应Tab：全部（供各视图调用）
# 依赖库：PyQt5, ctypes
#
# 【动效纪律】与知识库一致：
#   1. 一律尊重系统「减少动态效果」偏好（SPI_GETCLIENTAREAANIMATION）
#   2. 窗口淡入用 windowOpacity（不触碰子控件渲染，安全）
#   3. 小控件淡入用 QGraphicsOpacityEffect，动画结束必须 setGraphicsEffect(None)
#      （否则特效残留会栅格化控件渲染）
#   4. 不碰模态对话框（exec 会卡死动画回调，详见知识库）
#   5. 大控件（整页 Tab 等）不做 opacity 动画，避免栅格化卡顿
# ============================================================
import ctypes

from PyQt5.QtCore import QEasingCurve, QPropertyAnimation, QTimer
from PyQt5.QtWidgets import QGraphicsOpacityEffect

_ANIMATION_DISABLED = None  # None=尚未探测


def reduce_motion_enabled():
    """读取系统「减少动态效果」开关。True 表示用户关掉了界面动画，应跳过动效。"""
    global _ANIMATION_DISABLED
    if _ANIMATION_DISABLED is None:
        try:
            val = ctypes.c_uint(1)
            # SPI_GETCLIENTAREAANIMATION = 0x1042；val 为 0 表示动画已关闭
            ok = ctypes.windll.user32.SystemParametersInfoW(0x1042, 0, ctypes.byref(val), 0)
            _ANIMATION_DISABLED = bool(ok and not val.value)
        except Exception:
            _ANIMATION_DISABLED = False
    return _ANIMATION_DISABLED


def fade_in_window(widget, ms=320):
    """窗口入场淡入。用 windowOpacity，不影响子控件渲染。

    用法：在主窗口的 showEvent 或首次 show 后调用 fade_in_window(self)。
    """
    if reduce_motion_enabled():
        widget.setWindowOpacity(1.0)
        return
    widget.setWindowOpacity(0.0)
    anim = QPropertyAnimation(widget, b'windowOpacity', widget)
    anim.setDuration(ms)
    anim.setStartValue(0.0)
    anim.setEndValue(1.0)
    anim.setEasingCurve(QEasingCurve.OutCubic)
    widget._fade_anim = anim  # 持有引用，防止动画对象被回收
    anim.start()


def fade_in(widget, ms=260, delay=0):
    """小控件淡入（适合卡片、抽取结果行等小尺寸控件）。

    - 动画结束自动移除 opacity 特效（防栅格化残留）
    - delay>0 时延后启动，用于列表逐行错峰淡入
    """
    if reduce_motion_enabled():
        return

    def _play():
        eff = QGraphicsOpacityEffect(widget)
        widget.setGraphicsEffect(eff)
        anim = QPropertyAnimation(eff, b'opacity', widget)
        anim.setDuration(ms)
        anim.setStartValue(0.0)
        anim.setEndValue(1.0)
        anim.setEasingCurve(QEasingCurve.OutCubic)

        def _done():
            if widget.graphicsEffect() is eff:
                widget.setGraphicsEffect(None)
        anim.finished.connect(_done)
        widget._fade_anim = anim  # 持有引用，防止被回收
        anim.start()

    if delay > 0:
        QTimer.singleShot(delay, _play)
    else:
        _play()
