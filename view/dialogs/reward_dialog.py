# ============================================================
# 文件功能：新增奖励对话框
# 对应Tab：积分商店
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QComboBox, QSpinBox, QTextEdit
from model.style_config import get_config

class RewardDialog(QDialog):
    """弹窗：添加积分商店的奖品（名称/价格/等级/描述）"""
    def __init__(self, controller, parent=None):
        super().__init__(parent); self.ctrl = controller
        self.setWindowTitle("新增奖励"); self.setMinimumWidth(350)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(10)
        lo.addWidget(QLabel("奖励名称:"))
        self._name = QLineEdit(); lo.addWidget(self._name)
        lo.addWidget(QLabel("所需积分:"))
        self._cost = QSpinBox(); self._cost.setRange(1,999); self._cost.setValue(5); lo.addWidget(self._cost)
        lo.addWidget(QLabel("稀有度等级:"))
        self._cat = QComboBox(); self._cat.addItems(["普通","稀有","史诗","传说"]); lo.addWidget(self._cat)
        lo.addWidget(QLabel("奖励描述:"))
        self._desc = QTextEdit(); self._desc.setMaximumHeight(60); lo.addWidget(self._desc)
        bl = QHBoxLayout(); bl.addStretch()
        sb = QPushButton("保存"); sb.clicked.connect(self._on_save); sb.setStyleSheet(get_config().accent_btn()); bl.addWidget(sb)
        lo.addLayout(bl)

    def _on_save(self):
        n, c, cat, d = self._name.text().strip(), self._cost.value(), self._cat.currentText(), self._desc.toPlainText().strip()
        if not n or c<=0: return
        if self.ctrl.add_reward(n,c,cat,d): self.accept()