# ============================================================
# 文件功能：奖励背包对话框——查看学生拥有的未使用奖品
# 对应Tab：花名册 / 积分商店
# 依赖库：PyQt5
# ============================================================
import datetime
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QLabel, QPushButton, QScrollArea, QWidget, QHBoxLayout, QMessageBox
from PyQt5.QtCore import Qt
from model.style_config import get_config

class BackpackDialog(QDialog):
    """学生在积分商店兑换的奖品，存进背包。这个弹窗展示背包内容，可以点击使用。"""
    def __init__(self, student, controller, parent=None):
        super().__init__(parent); self.s = student; self.ctrl = controller
        self.setWindowTitle(f"{student.name} 的奖励背包"); self.resize(500, 400)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self)
        lo.addWidget(QLabel(f"{self.s.student_id} {self.s.name} 的未使用奖品"))
        sc = QScrollArea(); sc.setWidgetResizable(True)
        ct = QWidget(); cl = QVBoxLayout(ct); cl.setSpacing(6)
        # 只显示未使用的物品
        unused = [item for item in (self.s.items or []) if not item.used]
        if not unused:
            cl.addWidget(QLabel("背包是空的，快去积分商店兑换奖品吧！"))
        else:
            for it in unused:
                row = QHBoxLayout()
                dt = datetime.datetime.fromtimestamp(it.acquired_time).strftime('%Y-%m-%d')
                lbl = QLabel(f"{it.name} (获得于 {dt})")
                row.addWidget(lbl); row.addStretch()
                # "使用"按钮
                btn = QPushButton("使用")
                btn.setStyleSheet(get_config().accent_btn() + "border-radius:12px;padding:2px 12px;")
                # 判断是否为盲盒
                is_blind = (it.reward_id == 'r_blindbox')
                btn.clicked.connect(lambda checked, iid=it.id, ib=is_blind: self._on_use(iid, ib))
                row.addWidget(btn)
                cw = QWidget(); cw.setLayout(row); cl.addWidget(cw)
        cl.addStretch(); sc.setWidget(ct); lo.addWidget(sc, 1)

    def _on_use(self, iid, is_blind):
        """点击使用按钮后的处理"""
        if is_blind:
            # 盲盒需要特殊处理：打开后随机获得奖品
            msg = self.ctrl._use_blind_box(self.s, next(i for i, it in enumerate(self.s.items) if it.id == iid))
        else:
            msg = self.ctrl.use_item(self.s.id, iid)
        if msg: QMessageBox.information(self, "结果", msg)
        self._build()  # 刷新界面
        # 找到布局中的滚动区域，替换掉
        old = self.layout().itemAt(1)
        if old and old.widget(): old.widget().deleteLater()
        self._build()