# ============================================================
# 文件功能：学生卡片组件——花名册中每个学生的信息行
# 对应Tab：花名册
# 依赖库：PyQt5
# 使用方法：card = StudentCardWidget(student, config, group_name)
# ============================================================
from PyQt5.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton
from PyQt5.QtCore import Qt, pyqtSignal

# 小组左条纹色板：让花名册每行有色彩节奏，不再是满屏白
GROUP_STRIPES = ['#0fa88f', '#4c8de5', '#e76a9e', '#e8a93c', '#8b6fe8', '#22a06b']


def _stripe_color(group_name):
    """按小组名稳定取一个条纹色（未分组给中性灰蓝）"""
    if not group_name or group_name == '未分组':
        return '#aab4c4'
    h = sum(ord(ch) for ch in group_name)
    return GROUP_STRIPES[h % len(GROUP_STRIPES)]


class StudentCardWidget(QFrame):
    """学生名片：显示学号/姓名/小组/分数 + 5个操作按钮"""
    action_clicked = pyqtSignal(str, str)  # 信号：(操作名, 学生ID)

    def __init__(self, student, config, group_name='未分组', parent=None):
        super().__init__(parent)
        self.student = student
        self._build(config, group_name)

    def _build(self, config, group_name):
        s = self.student
        ch = config.get('card_height', 68)
        # 卡片外框（外框自身不占 padding，间距交给布局，避免按钮被挤偏）
        self.setStyleSheet(config.card_frame(padding='0px'))
        self.setFixedHeight(ch)
        # 小组色左条纹：打破白色单调，也给每行一点色彩身份
        self.setStyleSheet(self.styleSheet() + f"QFrame{{border-left:4px solid {_stripe_color(group_name)};}}")
        layout = QHBoxLayout(self); layout.setContentsMargins(14,6,10,6); layout.setSpacing(8)

        # 学号徽章
        id_lbl = QLabel(f"#{s.student_id}")
        id_lbl.setStyleSheet(config.pill(
            config.get('color_id_bg'), config.get('color_id_text'),
            border=config.get('color_card_border'), font_size=config.get('font_card_id', 20)))
        layout.addWidget(id_lbl)

        # 姓名
        nl = QLabel(s.name)
        nl.setStyleSheet(f"font-weight:bold; color:{config.get('color_name_text','#3e9a88')}; font-size:{config.get('font_card_name',26)}px;")
        nl.setMinimumWidth(config.get('student_name_min_width',100)); layout.addWidget(nl)

        # 小组标签
        gl = QLabel(group_name)
        gl.setStyleSheet(config.pill(
            config.get('color_group_tag_bg'), config.get('color_group_tag_text'),
            border=config.get('color_group_tag_border'), font_size=config.get('font_card_group',21)))
        layout.addWidget(gl)

        # 分数
        avail = s.available_points
        pl = QLabel(f"总分 {s.earned_points}  可用 {avail}")
        pl.setStyleSheet(config.pill(
            config.get('color_points_bg'), config.get('color_points_text', '#9a6a0a'),
            border=config.get('color_points_border'), font_size=config.get('font_card_points', 14))
            + "font-weight:600;")
        layout.addWidget(pl); layout.addStretch()

        # 5个操作按钮（圆形图标按钮，带悬停/按下反馈）
        ibs = config.get('icon_btn_size', 50)
        for txt, bgk, fgk, tip, act in [
            ("↩",'color_undo_bg','color_undo_text',"撤回","undo"),
            ("📋",'color_history_bg','color_history_text',"历史","history"),
            ("🎒",'color_backpack_bg','color_backpack_text',"背包","backpack"),
            ("🚚",'color_move_bg','color_move_text',"移动","move"),
            ("🗑",'color_delete_bg','color_delete_text',"删除","delete")]:
            btn = QPushButton(txt)
            btn.setStyleSheet(config.icon_btn(config.get(bgk), config.get(fgk), ibs))
            btn.setToolTip(tip)
            btn.setCursor(Qt.PointingHandCursor)
            btn.clicked.connect(lambda checked, a=act: self.action_clicked.emit(a, s.id))
            layout.addWidget(btn)