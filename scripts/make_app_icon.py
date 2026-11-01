# 生成应用图标：与标题栏 logo 同一套「marine 蓝潮薄荷心 + 白色四芒星」。
# 输出 assets/app_icon.png（1024）与 assets/app_icon.ico（16~256 多尺寸）。
import os
import sys

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import (QBrush, QColor, QGuiApplication, QImage, QLinearGradient,
                           QPainter, QPainterPath, QRadialGradient)

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PNG = os.path.join(BASE, 'assets', 'app_icon.png')
OUT_ICO = os.path.join(BASE, 'assets', 'app_icon.ico')

S = 1024
CORNER = 0.235 * S          # 标题栏 36px 图标 rad=11 → 约 30%；桌面图标略收一点更稳
STAR = 0.62 * S             # 星占图标高度比例（标题栏是 24/36≈0.67）

# IridescentFill "marine" 的调色板（与 QML 完全一致，顺序不变）
STOPS = [(0.00, '#4a78d8'), (0.18, '#82aaec'), (0.50, '#9fd6e6'),
         (0.82, '#82aaec'), (1.00, '#4a78d8')]
BLOBS = [
    (0.50, 0.62, 0.22, '#ffffff', 0.72),   # 中偏下白光斑
    (0.50, 0.30, 0.36, '#b8ecdc', 0.50),   # 薄荷蓝内晕
    (0.04, 0.50, 0.30, '#3a64c8', 0.45),   # 两端加深
    (0.96, 0.50, 0.30, '#3a64c8', 0.45),
]


def color(hex_str, alpha):
    c = QColor(hex_str)
    c.setAlphaF(alpha)
    return c


def render(size=S):
    img = QImage(size, size, QImage.Format_ARGB32_Premultiplied)
    img.fill(Qt.transparent)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing, True)
    p.setRenderHint(QPainter.SmoothPixmapTransform, True)

    # 圆角方形裁切
    path = QPainterPath()
    path.addRoundedRect(QRectF(0, 0, size, size), CORNER / S * size, CORNER / S * size)
    p.setClipPath(path)

    # 基底对角渐变
    g = QLinearGradient(0, 0, size, size)
    for pos, c in STOPS:
        g.setColorAt(pos, QColor(c))
    p.fillRect(QRectF(0, 0, size, size), QBrush(g))

    # 弥散色斑（径向到透明）
    for bx, by, br, c, a in BLOBS:
        cx, cy, r = bx * size, by * size, br * size
        rg = QRadialGradient(QPointF(cx, cy), r)
        rg.setColorAt(0.0, color(c, a))
        rg.setColorAt(1.0, color(c, 0.0))
        p.setPen(Qt.NoPen)
        p.setBrush(QBrush(rg))
        p.drawEllipse(QPointF(cx, cy), r, r)

    # 白色四芒星（与 CanvasIcon "sparkle" 同一条二次曲线路径）
    s = STAR / S * size
    k = s / 24.0
    star = QPainterPath()
    star.moveTo(12 * k, 3.6 * k)
    star.quadTo(13 * k, 11 * k, 20.4 * k, 12 * k)
    star.quadTo(13 * k, 13 * k, 12 * k, 20.4 * k)
    star.quadTo(11 * k, 13 * k, 3.6 * k, 12 * k)
    star.quadTo(11 * k, 11 * k, 12 * k, 3.6 * k)
    star.closeSubpath()
    p.translate((size - s) / 2, (size - s) / 2)
    p.setBrush(QColor('#ffffff'))
    p.setPen(Qt.NoPen)
    p.drawPath(star)
    p.end()
    return img


def main():
    app = QGuiApplication(sys.argv)
    img = render(S)
    if not img.save(OUT_PNG, 'PNG'):
        print('PNG 保存失败', OUT_PNG)
        return 1
    print('saved', OUT_PNG, img.width(), 'x', img.height())

    from PIL import Image
    im = Image.open(OUT_PNG).convert('RGBA')
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    im.save(OUT_ICO, format='ICO', sizes=sizes)
    print('saved', OUT_ICO, 'sizes', sizes)
    return 0


if __name__ == '__main__':
    sys.exit(main())
