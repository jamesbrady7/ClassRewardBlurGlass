# ============================================================
# 文件功能：积分历史对话框——查看某个学生的所有积分变动记录
# 对应Tab：花名册 / 积分商店
# 依赖库：PyQt5
# 使用方法：dialog = HistoryDialog(student, parent)
# ============================================================
import datetime
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QLabel, QScrollArea, QWidget
from PyQt5.QtCore import Qt

class HistoryDialog(QDialog):
    """显示学生所有的积分变动历史（加分/扣分/兑换/使用/盲盒）"""
    def __init__(self, student, parent=None):
        super().__init__(parent); self.s = student
        self.setWindowTitle(f"{student.name} 的积分历史"); self.resize(500, 400)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self)
        # 标题
        lo.addWidget(QLabel(f"学生 {self.s.student_id} {self.s.name} 的积分变动记录"))

        # 滚动区域
        sc = QScrollArea(); sc.setWidgetResizable(True)
        ct = QWidget(); cl = QVBoxLayout(ct); cl.setSpacing(4)
        # 把所有交易记录倒序排列（最新的在最上面）
        txns = sorted(self.s.transactions, key=lambda t: t.timestamp, reverse=True)
        # 类型映射：英文类型 → 中文+图标
        type_map = {'earn':'加分', 'deduct':'扣分', 'redeem':'兑换', 'use':'使用', 'blindbox':'盲盒'}
        for t in txns:
            dt = datetime.datetime.fromtimestamp(t.timestamp).strftime('%Y-%m-%d %H:%M')
            txt = f"{dt}  {type_map.get(t.type,t.type)}  {t.points}分"
            if t.description: txt += f" · {t.description}"
            lbl = QLabel(txt); lbl.setStyleSheet("border-bottom:1px dashed #ddd; padding:4px 0;")
            cl.addWidget(lbl)
        if not txns:
            cl.addWidget(QLabel("暂无记录"))
        cl.addStretch(); sc.setWidget(ct); lo.addWidget(sc, 1)