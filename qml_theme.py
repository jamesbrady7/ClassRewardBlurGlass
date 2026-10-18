# ============================================================
# 文件功能：QML 主题 token —— 把设计决策集中在一处，QML 里通过 Theme.xxx 取用
# 对应Tab：全部（QML UI 层）
# 依赖库：PySide6
#
# ── 昼夜模式（照搬原型的做法）─────────────────────────────
# 两套配色（_DAY / _NIGHT），切换时**在源头插值**：nightT 由 0 平滑推到 1（320ms），
# 每步 emit themeChanged → QML 里所有读 Theme.xxx 的绑定自动跟着变。
#   好处：**QML 侧一行都不用改**，所有颜色天然同步过渡，不会各走各的。
# ⚠️ 颜色属性必须 notify=themeChanged，且不能是 constant —— 否则切换时 QML 不会重读。
# ============================================================
import time

from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot

# 小组条纹色板（与旧版 view/widgets/student_card.py 保持一致）
GROUP_STRIPES = ['#0fa88f', '#4c8de5', '#e76a9e', '#e8a93c', '#8b6fe8', '#22a06b']


def stripe_color(group_name, seed=None):
    """按小组名稳定取一个条纹色；未分组时给中性灰蓝，若传了 seed（如学号）则按其稳定取色，避免卡片全灰"""
    if not group_name or group_name == '未分组':
        if seed is not None and str(seed):
            return GROUP_STRIPES[sum(ord(ch) for ch in str(seed)) % len(GROUP_STRIPES)]
        return '#aab4c4'
    return GROUP_STRIPES[sum(ord(ch) for ch in group_name) % len(GROUP_STRIPES)]


# ── 白天配色 ──────────────────────────────────────────────
_DAY = {
    'bgTop': '#f0f3f8', 'bgBottom': '#e4eaf2',
    'surface': '#ffffff', 'border': '#dfe5ee',
    'divider': '#e8edf3', 'inputBorder': '#d9dfe9',
    'textPrimary': '#1f2937', 'textSecondary': '#5b6472', 'textMuted': '#98a1b0',
    'accent': '#0fa88f', 'accentDark': '#0c8f7a', 'accentSoft': '#e3f6f1',
    'pink': '#e76a9e', 'pinkSoft': '#fde9f0',
    'blue': '#4c8de5', 'blueSoft': '#e8f1fd',
    'purple': '#8b6fe8', 'purpleSoft': '#efeafb',
    'amber': '#e8a93c', 'amberSoft': '#fcf3e0',
    'green': '#22a06b', 'greenSoft': '#e2f5ec',
    'red': '#e06050', 'redSoft': '#fce8e6',
    'gold': '#f0b429', 'goldBg': '#fff4da',
    'silver': '#9aa3b2', 'silverBg': '#edf0f6',
    'bronze': '#c9824a', 'bronzeBg': '#fbe9d8',
    'fillGlass': '#80ffffff', 'fillGlassHover': '#bdffffff',
    'fillShell': '#52ffffff', 'fillPill': '#ffffff',
    'aurora': '#6a7ce8', 'crimson': '#e63226',
    'groove': '#598c94ad',
    # 毛玻璃面 / 卡片底 / 图表 —— 逐条换成 token，深色底上才能跟着变
    'cardGlass': '#4dffffff',      # 页面卡片底（原来是硬编码 #4dffffff）
    'glassIdle': '#55ffffff',      # 搜索框 / 图标钮静止玻璃
    'glassHover': '#a8ffffff',     # 悬停提亮
    'glassActive': '#e0ffffff',    # 展开 / 聚焦
    'chipFace': '#d9ffffff',       # 学生方块未选中面
    'chartInk': '#0e8c77',         # 图表主色（折线 / 雷达多边形）
    'chartLabel': '#6b7d75',       # 图表刻度字
    'chartGrid': '#dfe9e4',        # 图表网格线
    'chartAxis': '#9fd8c6',        # 图表 X 轴
    # 标题栏 / 侧栏的面板底（穿透模式给"薄薄一层"，自绘模式更实一点）
    'titleTintGlass': '#59ffffff', 'titleTint': '#ccffffff', 'navTint': '#8cffffff',
}

# ── 夜间配色（参考原型 _NIGHT）──────────────────────────────
_NIGHT = {
    'bgTop': '#202438', 'bgBottom': '#12141f',
    'surface': '#232838', 'border': '#2c3345',
    'divider': '#262c3c', 'inputBorder': '#333a4d',
    'textPrimary': '#eef1f8', 'textSecondary': '#d8dce8', 'textMuted': '#98a0b8',
    'accent': '#2ec5a4', 'accentDark': '#3fd6b4', 'accentSoft': '#12332c',
    'pink': '#f07fae', 'pinkSoft': '#3a2330',
    'blue': '#6ba3f0', 'blueSoft': '#1d2a3d',
    'purple': '#a58cf5', 'purpleSoft': '#2a2440',
    'amber': '#f0b958', 'amberSoft': '#3a3220',
    'green': '#35c084', 'greenSoft': '#1c3329',
    'red': '#f07667', 'redSoft': '#3a2422',
    'gold': '#f0b429', 'goldBg': '#3a2f14',
    'silver': '#b8c0cf', 'silverBg': '#2a2f3b',
    'bronze': '#d19564', 'bronzeBg': '#3a2c20',
    'fillGlass': '#1fffffff', 'fillGlassHover': '#3dffffff',
    'fillShell': '#1affffff', 'fillPill': '#525d82',
    'aurora': '#7d8cf0', 'crimson': '#e64b40',
    'groove': '#29ffffff',
    'cardGlass': '#14ffffff',
    'glassIdle': '#1fffffff',
    'glassHover': '#3dffffff',
    'glassActive': '#4affffff',
    'chipFace': '#2bffffff',
    'chartInk': '#37c69f',
    'chartLabel': '#9fb0b8',
    'chartGrid': '#2a3340',
    'chartAxis': '#376f63',
    'titleTintGlass': '#3d0a0c14', 'titleTint': '#cc161a26', 'navTint': '#14ffffff',
}

ANIM_MS = 320        # 昼夜切换的颜色过渡时长（同原型）
STEP_MS = 16


def _parse(h):
    h = h.lstrip('#')
    if len(h) == 8:                       # AARRGGBB
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))
    return 255, int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _mix(c1, c2, t):
    """两种颜色按 t 线性插值。**保持输入的字数格式**：
    6 位进 6 位出、8 位进 8 位出 —— 有的调用方会对返回值做 .slice(1) 拼接 alpha。"""
    eight = len(c1.lstrip('#')) == 8 or len(c2.lstrip('#')) == 8
    a1, r1, g1, b1 = _parse(c1)
    a2, r2, g2, b2 = _parse(c2)
    f = lambda x, y: int(round(x + (y - x) * t))
    if eight:
        return '#%02x%02x%02x%02x' % (f(a1, a2), f(r1, r2), f(g1, g2), f(b1, b2))
    return '#%02x%02x%02x' % (f(r1, r2), f(g1, g2), f(b1, b2))


class Theme(QObject):
    """QML 全局主题（context property：Theme）。所有设计 token 都在这里。"""

    themeChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._night = False
        self._t = 0.0                     # 0=白天 1=夜间（平滑量）
        self._target = 0.0
        self._timer = QTimer(self)
        self._timer.setInterval(STEP_MS)
        self._timer.timeout.connect(self._step)
        self._last = time.monotonic()

    # ---- 昼夜切换 ----
    @Property(bool, notify=themeChanged)
    def night(self):
        return self._night

    @night.setter
    def night(self, v):
        v = bool(v)
        if v == self._night:
            return
        self._night = v
        self._target = 1.0 if v else 0.0
        self._last = time.monotonic()
        self._timer.start()

    @Slot()
    def toggleNight(self):
        self.night = not self._night

    def _step(self):
        # ⚠️ 按**真实经过的时间**推进，不是按固定步长：切换时 QML 绑定大量重算，
        #    定时器会被拖慢（实测 320ms 的过渡在墙钟上跑了 600ms 还没完）。
        now = time.monotonic()
        step = (now - self._last) * 1000.0 / float(ANIM_MS)
        self._last = now
        if self._t < self._target:
            self._t = min(self._target, self._t + step)
        else:
            self._t = max(self._target, self._t - step)
        if abs(self._t - self._target) < 1e-6:
            self._timer.stop()
        self.themeChanged.emit()

    def _c(self, key):
        """按当前昼夜进度取色。"""
        d = _DAY[key]
        n = _NIGHT.get(key, d)
        return d if self._t <= 0 else (n if self._t >= 1 else _mix(d, n, self._t))

    # ---- 颜色 ----
    @Property(str, notify=themeChanged)
    def bgTop(self):
        return self._c('bgTop')

    @Property(str, notify=themeChanged)
    def bgBottom(self):
        return self._c('bgBottom')

    @Property(str, notify=themeChanged)
    def surface(self):
        return self._c('surface')

    @Property(str, notify=themeChanged)
    def border(self):
        return self._c('border')

    @Property(str, notify=themeChanged)
    def divider(self):
        return self._c('divider')

    @Property(str, notify=themeChanged)
    def inputBorder(self):
        return self._c('inputBorder')

    @Property(str, notify=themeChanged)
    def groove(self):
        return self._c('groove')

    @Property(str, notify=themeChanged)
    def textPrimary(self):
        return self._c('textPrimary')

    @Property(str, notify=themeChanged)
    def textSecondary(self):
        return self._c('textSecondary')

    @Property(str, notify=themeChanged)
    def textMuted(self):
        return self._c('textMuted')

    @Property(str, notify=themeChanged)
    def accent(self):
        return self._c('accent')

    @Property(str, notify=themeChanged)
    def accentDark(self):
        return self._c('accentDark')

    @Property(str, notify=themeChanged)
    def accentSoft(self):
        return self._c('accentSoft')

    @Property(str, notify=themeChanged)
    def pink(self):
        return self._c('pink')

    @Property(str, notify=themeChanged)
    def pinkSoft(self):
        return self._c('pinkSoft')

    @Property(str, notify=themeChanged)
    def blue(self):
        return self._c('blue')

    @Property(str, notify=themeChanged)
    def blueSoft(self):
        return self._c('blueSoft')

    @Property(str, notify=themeChanged)
    def purple(self):
        return self._c('purple')

    @Property(str, notify=themeChanged)
    def purpleSoft(self):
        return self._c('purpleSoft')

    @Property(str, notify=themeChanged)
    def amber(self):
        return self._c('amber')

    @Property(str, notify=themeChanged)
    def amberSoft(self):
        return self._c('amberSoft')

    @Property(str, notify=themeChanged)
    def green(self):
        return self._c('green')

    @Property(str, notify=themeChanged)
    def greenSoft(self):
        return self._c('greenSoft')

    @Property(str, notify=themeChanged)
    def red(self):
        return self._c('red')

    @Property(str, notify=themeChanged)
    def redSoft(self):
        return self._c('redSoft')

    # ---- 排名 ----
    @Property(str, notify=themeChanged)
    def gold(self):
        return self._c('gold')

    @Property(str, notify=themeChanged)
    def goldBg(self):
        return self._c('goldBg')

    @Property(str, notify=themeChanged)
    def silver(self):
        return self._c('silver')

    @Property(str, notify=themeChanged)
    def silverBg(self):
        return self._c('silverBg')

    @Property(str, notify=themeChanged)
    def bronze(self):
        return self._c('bronze')

    @Property(str, notify=themeChanged)
    def bronzeBg(self):
        return self._c('bronzeBg')

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

    # ---- 圆形按钮的玻璃面 ----
    @Property(str, notify=themeChanged)
    def fillGlass(self):
        return self._c('fillGlass')

    @Property(str, notify=themeChanged)
    def fillGlassHover(self):
        return self._c('fillGlassHover')

    # ---- 分段 tab ----
    @Property(str, notify=themeChanged)
    def fillShell(self):
        return self._c('fillShell')

    @Property(str, notify=themeChanged)
    def fillPill(self):
        return self._c('fillPill')

    # ---- 加减按钮主色 ----
    @Property(str, notify=themeChanged)
    def aurora(self):
        return self._c('aurora')

    @Property(str, notify=themeChanged)
    def crimson(self):
        return self._c('crimson')

    # ---- 页面卡片 / 玻璃面（本轮新增，供替换硬编码用）----
    @Property(str, notify=themeChanged)
    def cardGlass(self):
        return self._c('cardGlass')

    @Property(str, notify=themeChanged)
    def glassIdle(self):
        return self._c('glassIdle')

    @Property(str, notify=themeChanged)
    def glassHover(self):
        return self._c('glassHover')

    @Property(str, notify=themeChanged)
    def glassActive(self):
        return self._c('glassActive')

    @Property(str, notify=themeChanged)
    def chipFace(self):
        return self._c('chipFace')

    # ---- 面板底（标题栏 / 侧栏）----
    @Property(str, notify=themeChanged)
    def titleTintGlass(self):
        return self._c('titleTintGlass')

    @Property(str, notify=themeChanged)
    def titleTint(self):
        return self._c('titleTint')

    @Property(str, notify=themeChanged)
    def navTint(self):
        return self._c('navTint')

    # ---- 图表 ----
    @Property(str, notify=themeChanged)
    def chartInk(self):
        return self._c('chartInk')

    @Property(str, notify=themeChanged)
    def chartLabel(self):
        return self._c('chartLabel')

    @Property(str, notify=themeChanged)
    def chartGrid(self):
        return self._c('chartGrid')

    @Property(str, notify=themeChanged)
    def chartAxis(self):
        return self._c('chartAxis')

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

    # ---- 奖励分类配色（商店 / 背包共用）----
    @Slot(str, result=str)
    def catSoft(self, cat):
        return {'普通': self.blueSoft, '稀有': self.purpleSoft,
                '史诗': self.amberSoft, '传说': self.redSoft}.get(cat, '')

    @Slot(str, result=str)
    def catFg(self, cat):
        return {'普通': self.blue, '稀有': self.purple,
                '史诗': self.amber, '传说': self.red}.get(cat, '')
