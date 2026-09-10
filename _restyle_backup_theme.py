# ============================================================
# 文件功能：QML 主题 token —— 把设计决策集中在一处，QML 里通过 Theme.xxx 取用
# 对应Tab：全部（QML UI 层）
# 依赖库：PySide6
#
# 设计语言（与 QSS 版一致，QML 侧落地）：
#   「清新 · 高级」明亮主题 —— 近白灰蓝背景 + 白色卡片 + 翡翠主色
# ============================================================
from PySide6.QtCore import QObject, Property

# 小组条纹色板：蓝系为主（无紫），绿/玫瑰仅作辨识
GROUP_STRIPES = ['#4d82bd', '#7e9c85', '#c08f97', '#86a4ae', '#6f9cc9', '#5d7fa8']


def stripe_color(group_name, seed=None):
    """按小组名稳定取一个条纹色；未分组时给中性灰蓝，若传了 seed（如学号）则按其稳定取色，避免卡片全灰"""
    if not group_name or group_name == '未分组':
        if seed is not None and str(seed):
            return GROUP_STRIPES[sum(ord(ch) for ch in str(seed)) % len(GROUP_STRIPES)]
        return '#aab4c4'
    return GROUP_STRIPES[sum(ord(ch) for ch in group_name) % len(GROUP_STRIPES)]


class Theme(QObject):
    """QML 全局主题（context property：Theme）。所有设计 token 都在这里。"""

    # ---- 颜色（莫兰迪灰调体系，主色=雾霾蓝）----
    @Property(str, constant=True)
    def bgTop(self):
        return '#e6ebf4'

    @Property(str, constant=True)
    def bgBottom(self):
        return '#d8e2f0'

    @Property(str, constant=True)
    def surface(self):
        return '#fcfcfb'

    @Property(str, constant=True)
    def border(self):
        return '#d9dee4'

    @Property(str, constant=True)
    def divider(self):
        return '#e4e8ed'

    @Property(str, constant=True)
    def inputBorder(self):
        return '#c9d1da'

    @Property(str, constant=True)
    def textPrimary(self):
        return '#454a52'

    @Property(str, constant=True)
    def textSecondary(self):
        return '#6a7078'

    @Property(str, constant=True)
    def textMuted(self):
        return '#9aa1aa'

    # —— 玻璃 token（伪磨砂：半透白 + 白描边）——
    @Property(str, constant=True)
    def glass(self):
        return '#a8ffffff'          # 66% 白玻璃

    @Property(str, constant=True)
    def glassStrong(self):
        return '#c4ffffff'          # 77% 白玻璃（信息密集处用）

    @Property(str, constant=True)
    def glassBorder(self):
        return '#e8ffffff'          # 91% 白描边（玻璃高光边）

    # 主色：更正的蓝（去紫味、提饱和）
    @Property(str, constant=True)
    def accent(self):
        return '#4d82bd'

    @Property(str, constant=True)
    def accentDark(self):
        return '#3c689b'

    @Property(str, constant=True)
    def accentSoft(self):
        return '#dbe8f6'

    @Property(str, constant=True)
    def pink(self):
        return '#c08f97'

    @Property(str, constant=True)
    def pinkSoft(self):
        return '#f2e5e7'

    @Property(str, constant=True)
    def blue(self):
        return '#6f9cc9'

    @Property(str, constant=True)
    def blueSoft(self):
        return '#e0eaf6'

    # 紫→板岩蓝（去紫味）
    @Property(str, constant=True)
    def purple(self):
        return '#8aa0be'

    @Property(str, constant=True)
    def purpleSoft(self):
        return '#e3ebf5'

    @Property(str, constant=True)
    def amber(self):
        return '#c3a377'

    @Property(str, constant=True)
    def amberSoft(self):
        return '#f2e9db'

    @Property(str, constant=True)
    def green(self):
        return '#7e9c85'

    @Property(str, constant=True)
    def greenSoft(self):
        return '#e3eae1'

    @Property(str, constant=True)
    def red(self):
        return '#b4807d'

    @Property(str, constant=True)
    def redSoft(self):
        return '#f0e1df'

    # ---- 排名 ----
    @Property(str, constant=True)
    def gold(self):
        return '#c9a96b'

    @Property(str, constant=True)
    def goldBg(self):
        return '#f3ecdc'

    @Property(str, constant=True)
    def silver(self):
        return '#a6abb1'

    @Property(str, constant=True)
    def silverBg(self):
        return '#eaecef'

    @Property(str, constant=True)
    def bronze(self):
        return '#b98a66'

    @Property(str, constant=True)
    def bronzeBg(self):
        return '#f1e5da'

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
