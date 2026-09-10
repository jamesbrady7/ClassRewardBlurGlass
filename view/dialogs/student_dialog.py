# ============================================================
# 文件功能：添加学生对话框
# 对应Tab：花名册
# 依赖库：PyQt5
# 使用方法：dialog = StudentDialog(controller, parent); dialog.exec_()
# ============================================================
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QComboBox
from model.style_config import get_config

class StudentDialog(QDialog):
    """弹出一个小窗口，用于添加一个学生。填写姓名、学号、选择小组后点击保存。"""
    def __init__(self, controller, parent=None):
        super().__init__(parent); self.ctrl = controller
        self.setWindowTitle("添加学生"); self.setMinimumWidth(350)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(12)
        lo.addWidget(QLabel("姓名:")); self._name = QLineEdit(); lo.addWidget(self._name)
        lo.addWidget(QLabel("学号 (01-50):")); self._sid = QLineEdit(); lo.addWidget(self._sid)
        lo.addWidget(QLabel("所属小组:")); self._gp = QComboBox(); self._gp.addItem("无小组","")
        cls = self.ctrl.current_class()
        if cls:
            for g in cls.groups: self._gp.addItem(g.name, g.id)
        lo.addWidget(self._gp)
        bl = QHBoxLayout(); bl.addStretch()
        sb = QPushButton("保存"); sb.setStyleSheet(get_config().accent_btn())
        sb.clicked.connect(self._on_save); bl.addWidget(sb); lo.addLayout(bl)

    def _on_save(self):
        n, sid = self._name.text().strip(), self._sid.text().strip()
        if not n or not sid: return
        gid = self._gp.currentData()
        if self.ctrl.add_student(sid, n, gid): self.accept()
        else: from PyQt5.QtWidgets import QMessageBox; QMessageBox.warning(self,"提示","添加失败（学号重复或人数已满）")