# ============================================================
# 文件功能：小组操作对话框（新建小组）
# 对应Tab：小组榜
# 依赖库：PyQt5
# 使用方法：dialog = GroupDialog(controller, parent)
# ============================================================
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QGridLayout, QWidget, QScrollArea
from PyQt5.QtCore import Qt
from model.style_config import get_config

class GroupDialog(QDialog):
    """弹出窗口：输入小组名称，选择初始成员，点击创建。"""
    def __init__(self, controller, parent=None):
        super().__init__(parent); self.ctrl = controller
        self._picked = set()
        self.setWindowTitle("新建小组"); self.setMinimumSize(400,300)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self); lo.addWidget(QLabel("小组名称:"))
        self._name = QLineEdit(); lo.addWidget(self._name)
        lo.addWidget(QLabel("选择成员（可选）:"))

        cls = self.ctrl.current_class()
        sc = QScrollArea(); sc.setWidgetResizable(True)
        ct = QWidget(); gl = QGridLayout(ct); gl.setSpacing(4)
        if cls:
            students = sorted(cls.students, key=lambda s: int(s.student_id) if s.student_id.isdigit() else 0)
            unassigned = [s for s in students if not s.group_id]
            c = get_config()
            for idx, s in enumerate(unassigned):
                btn = QPushButton(f"{s.student_id}\n{s.name[:3]}"); btn.setCheckable(True); btn.setFixedSize(60,52)
                btn.setStyleSheet(
                    f"QPushButton{{background:{c.get('color_tab_bg','#f0f3f9')};"
                    f"border:1px solid {c.get('color_card_border','#e6eaf2')};"
                    f"border-radius:12px;font-size:11px;color:{c.get('color_tab_text','#6b7484')};}}"
                    f" QPushButton:checked{{background:{c.get('color_accent_bg','#0fa88f')};color:white;}}")
                btn.toggled.connect(lambda c, sid=s.id: self._picked.add(sid) if c else self._picked.discard(sid))
                gl.addWidget(btn, idx//8, idx%8)
        sc.setWidget(ct); lo.addWidget(sc,1)

        bl = QHBoxLayout(); bl.addStretch()
        sb = QPushButton("创建"); sb.clicked.connect(self._on_create); sb.setStyleSheet(get_config().accent_btn()); bl.addWidget(sb)
        lo.addLayout(bl)

    def _on_create(self):
        name = self._name.text().strip()
        if not name: return
        if self.ctrl.add_group(name, list(self._picked)): self.accept()