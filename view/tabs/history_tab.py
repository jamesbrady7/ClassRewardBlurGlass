# ============================================================
# 文件功能：每日历史Tab——按日期分组展示所有积分变动
# 对应Tab：每日历史
# 依赖库：PyQt5, datetime, collections
# ============================================================
import datetime
from collections import defaultdict
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QScrollArea
from PyQt5.QtCore import Qt

class HistoryTab(QWidget):
    """每日历史：按日期分组显示所有学生的加减分/兑换/使用记录"""
    def __init__(self, ctrl, mw, parent=None):
        super().__init__(parent); self.ctrl = ctrl; self.mw = mw; self._build()

    @property
    def cfg(self):
        return self.mw._config if hasattr(self.mw, '_config') else None

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(12); tl = QLabel("每日历史"); tl.setStyleSheet(self.cfg.section_title_qss()); lo.addWidget(tl)
        sc = QScrollArea(); sc.setWidgetResizable(True)
        self._ct = QWidget(); self._cl = QVBoxLayout(self._ct)
        self._cl.setSpacing(8); self._cl.addStretch()
        sc.setWidget(self._ct); lo.addWidget(sc, 1)

    def refresh(self):
        cls = self.ctrl.current_class()
        if not cls: return
        while self._cl.count() > 1:
            it = self._cl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        all_tx = []
        for s in cls.students:
            for t in s.transactions:
                all_tx.append({'ts': t.timestamp, 'sn': s.name, 'sid': s.student_id,
                              'type': t.type, 'pts': t.points, 'desc': t.description})
        all_tx.sort(key=lambda x: x['ts'], reverse=True)
        by_date = defaultdict(list)
        for tx in all_tx:
            dt = datetime.datetime.fromtimestamp(tx['ts']); by_date[dt.strftime('%Y-%m-%d')].append(tx)
        tm = {'earn': '加分', 'deduct': '扣分', 'redeem': '兑换', 'use': '使用', 'blindbox': '盲盒'}
        c = self.cfg; fh = c.get('font_history', 14) if c else 14
        for d in sorted(by_date.keys(), reverse=True):
            dl = QLabel(f"📅 {d}"); dl.setStyleSheet(f"font-weight:bold;color:{c.get('color_section_title','#e07aa0') if c else '#e07aa0'};font-size:{fh+2}px;margin-top:8px;")
            self._cl.insertWidget(self._cl.count() - 1, dl)
            for tx in by_date[d]:
                ds = datetime.datetime.fromtimestamp(tx['ts']).strftime('%H:%M:%S')
                txt = f"{ds}  {tx['sn']}({tx['sid']})  {tm.get(tx['type'], tx['type'])}  {tx['pts']}分"
                if tx['desc']: txt += f" · {tx['desc']}"
                il = QLabel(txt); il.setStyleSheet(f"padding:4px 8px;border-bottom:1px dashed {c.get('color_card_border','#c9e8dc') if c else '#c9e8dc'};color:#556a63;font-size:{fh}px;")
                self._cl.insertWidget(self._cl.count() - 1, il)
        if not all_tx:
            e = QLabel("暂无记录"); e.setAlignment(Qt.AlignCenter); self._cl.insertWidget(0, e)