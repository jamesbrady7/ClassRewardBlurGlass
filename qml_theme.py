# ============================================================
# 文件功能：QML 主题 token —— 把设计决策集中在一处，QML 里通过 Theme.xxx 取用
# 对应Tab：全部（QML UI 层）
# 依赖库：PySide6
#
# 设计语言（与 QSS 版一致，QML 侧落地）：
#   「清新 · 高级」明亮主题 —— 近白灰蓝背景 + 白色卡片 + 翡翠主色
# ============================================================
from PySide6.QtCore import QObject, Property

# 小组条纹色板（与旧版 view/widgets/student_card.py 保持一致）
GROUP_STRIPES = ['#0fa88f', '#4c8de5', '#e76a9e', '#e8a93c', '#8b6fe8', '#22a06b']


def stripe_color(group_name, seed=None):
    """按小组名稳定取一个条纹色；未分组时给中性灰蓝，若传了 seed（如学号）则按其稳定取色，避免卡片全灰"""
    if not group_name or group_name == '未分组':
        if seed is not None and str(seed):
            return GROUP_STRIPES[sum(ord(ch) for ch in str(seed)) % len(GROUP_STRIPES)]
        return '#aab4c4'
    return GROUP_STRIPES[sum(ord(ch) for ch in group_name) % len(GROUP_STRIPES)]


class Theme(QObject):
    """QML 全局主题（context property：Theme）。所有设计 token 都在这里。"""

    # ---- 颜色 ----
    @Property(str, constant=True)
    def bgTop(self):
        return '#f0f3f8'

    @Property(str, constant=True)
    def bgBottom(self):
        return '#e4eaf2'

    @Property(str, constant=True)
    def surface(self):
        return '#ffffff'

    @Property(str, constant=True)
    def border(self):
        return '#dfe5ee'

    @Property(str, constant=True)
    def divider(self):
        return '#e8edf3'

    @Property(str, constant=True)
    def inputBorder(self):
        return '#d9dfe9'

    @Property(str, constant=True)
    def textPrimary(self):
        return '#1f2937'

    @Property(str, constant=True)
    def textSecondary(self):
        return '#5b6472'

    @Property(str, constant=True)
    def textMuted(self):
        return '#98a1b0'

    @Property(str, constant=True)
    def accent(self):
        return '#0fa88f'

    @Property(str, constant=True)
    def accentDark(self):
        return '#0c8f7a'

    @Property(str, constant=True)
    def accentSoft(self):
        return '#e3f6f1'

    @Property(str, constant=True)
    def pink(self):
        return '#e76a9e'

    @Property(str, constant=True)
    def pinkSoft(self):
        return '#fde9f0'

    @Property(str, constant=True)
    def blue(self):
        return '#4c8de5'

    @Property(str, constant=True)
    def blueSoft(self):
        return '#e8f1fd'

    @Property(str, constant=True)
    def purple(self):
        return '#8b6fe8'

    @Property(str, constant=True)
    def purpleSoft(self):
        return '#efeafb'

    @Property(str, constant=True)
    def amber(self):
        return '#e8a93c'

    @Property(str, constant=True)
    def amberSoft(self):
        return '#fcf3e0'

    @Property(str, constant=True)
    def green(self):
        return '#22a06b'

    @Property(str, constant=True)
    def greenSoft(self):
        return '#e2f5ec'

    @Property(str, constant=True)
    def red(self):
        return '#e06050'

    @Property(str, constant=True)
    def redSoft(self):
        return '#fce8e6'

    # ---- 排名 ----
    @Property(str, constant=True)
    def gold(self):
        return '#f0b429'

    @Property(str, constant=True)
    def goldBg(self):
        return '#fff4da'

    @Property(str, constant=True)
    def silver(self):
        return '#9aa3b2'

    @Property(str, constant=True)
    def silverBg(self):
        return '#edf0f6'

    @Property(str, constant=True)
    def bronze(self):
        return '#c9824a'

    @Property(str, constant=True)
    def bronzeBg(self):
        return '#fbe9d8'

    # ---- 字体 ----
    @Property(str, constant=True)
    def fontFamily(self):
        return 'MiSans'

    @Property(int, constant=True)
    def fontTitle(self):
        return 24

    @Property(int, constant=True)
    def fontSection(self):
        return 16

    @Property(int, constant=True)
    def fontBody(self):
        return 13

    @Property(int, constant=True)
    def fontSmall(self):
        return 12

    @Property(int, constant=True)
    def fontBig(self):
        return 15

    # ---- 加减按钮配色（取自毛玻璃原型「圆形按钮 16 / 15」的主色）----
    # 那两个按钮本身是多色杂糅；这里只取其代表色 —— 形状与渲染都不变，只换颜色
    @Property(str, constant=True)
    def aurora(self):
        return '#6a7ce8'      # 原型 16 aurora（极光杂糅：浅紫→蓝→青）的主色

    @Property(str, constant=True)
    def crimson(self):
        return '#e63226'      # 原型 15 crimson（深红黑晕）的主色

    # ---- 尺寸 ----
    @Property(int, constant=True)
    def radius(self):
        return 14

    @Property(int, constant=True)
    def radiusSmall(self):
        return 8

    @Property(int, constant=True)
    def radiusPill(self):
        return 999

    @Property(int, constant=True)
    def spacing(self):
        return 12

    @Property(int, constant=True)
    def contentMargin(self):
        return 24
