# ============================================================
# 文件功能：小组卡片组件——小组榜中每个小组的信息卡
# 对应Tab：小组榜（GroupTab）
# 依赖库：PyQt5
# 使用方法：card = GroupCardWidget(group, points, members, config, rank)
# ============================================================
from PyQt5.QtWidgets import QFrame, QVBoxLayout, QHBoxLayout, QLabel, QPushButton
from PyQt5.QtCore import Qt, pyqtSignal

class GroupCardWidget(QFrame):
    """小组卡片：显示排名徽章、组名、分数、成员标签和操作按钮"""
    action_clicked = pyqtSignal(str, str)  # (操作, group_id)
    rename_requested = pyqtSignal(str)     # group_id

    # 前三名的勋章配置：(文字, 背景色, 文字色, 卡片背景, 卡片边框)
    RANK = {1:("🥇NO.1",'#f0b429','white','#fff8e8','#f0c56b'),
            2:("🥈NO.2",'#9aa3b2','white','#f3f5f9','#d6dce6'),
            3:("🥉NO.3",'#c9824a','white','#fdf1e8','#e5b894')}

    def __init__(self, group, total_points, members, config, rank=0, parent=None):
        super().__init__(parent); self.group = group
        self._build(group, total_points, members, config, rank)

    def _build(self, g, pts, members, c, rank):
        # 卡片外框（默认薄荷绿；前三名用勋章专属底色）
        cbg, cbr = None, None
        if rank in self.RANK: _, _, _, cbg, cbr = self.RANK[rank]
        self.setStyleSheet(c.card_frame(
            bg=cbg or c.get('color_card_bg', '#ffffff'),
            border=cbr or c.get('color_card_border', '#e6eaf2'),
            radius=14, padding='0px'))
        ml = QVBoxLayout(self); ml.setContentsMargins(14,10,14,10); ml.setSpacing(8)
        hd = QHBoxLayout()
        # 排名徽章
        if rank in self.RANK:
            t,bg,fg,_,_ = self.RANK[rank]; bd = QLabel(t)
            bd.setStyleSheet(f"background:{bg};color:{fg};font-weight:bold;border-radius:15px;padding:2px 14px;border:2px solid white;")
            hd.addWidget(bd)
        # 组名（可点击改名）
        tff = c.get('font_title_family', 'MiSans')
        nb = QPushButton(g.name)
        nb.setStyleSheet(f"background:transparent;border:none;font-family:'{tff}';font-weight:600;color:{c.get('color_group_title_text','#1f2937')};font-size:15px;text-align:left;padding:0;")
        nb.setCursor(Qt.PointingHandCursor); nb.clicked.connect(lambda:self.rename_requested.emit(g.id)); hd.addWidget(nb); hd.addStretch()
        # 分数（翡翠青药丸）
        pl = QLabel(f"{pts} 分")
        pl.setStyleSheet(c.pill(c.get('color_accent_bg','#0fa88f'), 'white', radius=999,
                                padding='3px 14px') + "font-weight:600;")
        hd.addWidget(pl)
        # 按钮
        gbs = c.get('group_btn_size',34)
        for txt, bg, fg, a in [("➕",'#d6f0e6','#0b7a66','addGroupPoints'),
                               ("➖",'#fde9f0','#c2487a','subtractGroupPoints'),
                               ("🗑",'#fceae8','#c84a3e','deleteGroup')]:
            b=QPushButton(txt); b.setStyleSheet(c.icon_btn(bg, fg, gbs, font_size=18)); b.setCursor(Qt.PointingHandCursor)
            b.clicked.connect(lambda checked,act=a: self.action_clicked.emit(act,g.id)); hd.addWidget(b)
        ml.addLayout(hd)
        # 成员（小药丸）
        if members:
            mt=QHBoxLayout(); mt.setSpacing(5)
            for m in members:
                t=QLabel(f"{m['student_id']} {m['name']}")
                t.setStyleSheet(c.pill(c.get('color_tab_bg','#f0f3f9'), c.get('color_tab_text','#6b7484'),
                                       radius=999, font_size=12, padding='2px 10px'))
                mt.addWidget(t)
            mt.addStretch(); ml.addLayout(mt)
        else:
            e = QLabel("暂无成员"); e.setStyleSheet("color:#9aa4b2;"); ml.addWidget(e)