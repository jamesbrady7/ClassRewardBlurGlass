# ============================================================
# 文件功能：移动学生到其他小组对话框
# 对应Tab：花名册
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QComboBox
from model.style_config import get_config

class MoveGroupDialog(QDialog):
    """把学生从一个小组移动到另一个小组"""
    def __init__(self, controller, student, parent=None):
        super().__init__(parent); self.ctrl = controller; self.s = student
        self.setWindowTitle(f"移动 {student.name}"); self.setMinimumWidth(300)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(10)
        lo.addWidget(QLabel(f"将 {self.s.student_id} {self.s.name} 移动到:"))
        self._gp = QComboBox(); self._gp.addItem("无小组","")
        cls = self.ctrl.current_class()
        if cls:
            for g in cls.groups:
                self._gp.addItem(g.name, g.id)
                if g.id == self.s.group_id: self._gp.setCurrentIndex(self._gp.count()-1)
        lo.addWidget(self._gp)
        bl = QHBoxLayout(); bl.addStretch()
        sb = QPushButton("确认移动"); sb.clicked.connect(self._on_move); sb.setStyleSheet(get_config().accent_btn()); bl.addWidget(sb)
        lo.addLayout(bl)

    def _on_move(self):
        gid = self._gp.currentData()
        if self.ctrl.move_student_group(self.s.id, gid): self.accept()