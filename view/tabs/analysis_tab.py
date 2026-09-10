# ============================================================
# 文件功能：数据分析Tab——六维雷达图 + 学习趋势折线图
# 对应Tab：数据分析
# 依赖库：PyQt5, view.charts
# ============================================================
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QLineEdit, QFrame, QScrollArea, QMessageBox)
from PyQt5.QtCore import Qt
from view.charts import RadarChartWidget, TrendChartWidget

class AnalysisTab(QWidget):
    """数据分析：展示六维雷达图和学习趋势折线图"""
    def __init__(self, ctrl, mw, parent=None):
        super().__init__(parent); self.ctrl = ctrl; self.mw = mw
        self._mode = 'all'; self._q = ''; self._hide = False; self._build()

    @property
    def cfg(self):
        return self.mw._config if hasattr(self.mw, '_config') else None

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(12); tl = QLabel("数据分析"); tl.setStyleSheet(self.cfg.section_title_qss()); lo.addWidget(tl)

        # 工具栏
        tb = QHBoxLayout()
        self._ab = QPushButton("全班"); self._ab.setCheckable(True); self._ab.setChecked(True)
        self._ab.clicked.connect(self._on_all); tb.addWidget(self._ab)
        tb.addWidget(QLabel("|"))
        self._si = QLineEdit(); self._si.setPlaceholderText("输入学号"); self._si.setFixedWidth(100)
        self._si.returnPressed.connect(self._on_search); tb.addWidget(self._si)
        sb = QPushButton("搜索", clicked=self._on_search); sb.setStyleSheet(self.cfg.accent_btn()); tb.addWidget(sb)
        self._hb = QPushButton("隐藏姓名"); self._hb.clicked.connect(self._on_hide); tb.addWidget(self._hb)
        self._ml = QLabel("全班模式"); tb.addWidget(self._ml); tb.addStretch(); lo.addLayout(tb)

        # 图表容器（不使用 QScrollArea，因为会拦截鼠标点击事件）
        self._ct = QWidget(); self._cl = QVBoxLayout(self._ct)
        self._cl.setSpacing(16); self._cl.addStretch()
        lo.addWidget(self._ct, 1)

    def refresh(self):
        cls = self.ctrl.current_class()
        if not cls: return
        while self._cl.count() > 1:
            it = self._cl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        if not cls.students: self._add_empty("暂无学生数据"); return

        # 判断显示模式
        if self._mode == 'all':
            st = sorted(cls.students, key=lambda s: int(s.student_id) if s.student_id.isdigit() else 0)
            self._ml.setText(f"全班模式({len(st)}人)")
        else:
            q = self._q.strip()
            if not q: self._add_empty("输入学号后点击搜索"); return
            st = [s for s in cls.students if s.student_id == q]
            if not st: self._add_empty(f'未找到学号"{q}"'); return
            self._ml.setText(f"单人模式({st[0].student_id} {st[0].name})")

        # 画图
        sd = self.ctrl.compute_category_scores()
        c = self.cfg; rs = c.get('chart_radar_size', 300) if c else 300
        ts = c.get('chart_trend_size', 300) if c else 300
        for s in st:
            data = sd.get(s.id)
            if not data: continue
            dn = '***' if self._hide else s.name
            c = self.cfg
            fr = QFrame(); fr.setStyleSheet(c.card_frame(radius=18, padding='10px') if c else "")
            fl = QVBoxLayout(fr)
            tl = QLabel(f"#{s.student_id} {dn}", alignment=Qt.AlignCenter)
            if c: tl.setStyleSheet(f"font-weight:bold;font-size:{c.get('font_card_name',22)}px;color:{c.get('color_name_text','#3e9a88')};")
            fl.addWidget(tl)
            cr = QHBoxLayout()
            rw = RadarChartWidget(config=c); rw.draw_chart(data['scores']); rw.setMinimumSize(rs, rs); cr.addWidget(rw)
            tw = TrendChartWidget(config=c); tw.draw_chart(s.transactions); tw.setMinimumSize(ts, ts); cr.addWidget(tw)
            fl.addLayout(cr); self._cl.insertWidget(self._cl.count() - 1, fr)

    def _add_empty(self, txt):
        e = QLabel(txt); e.setAlignment(Qt.AlignCenter); e.setStyleSheet("color:#888;")
        self._cl.insertWidget(self._cl.count() - 1, e)

    def _on_all(self): self._mode = 'all'; self._q = ''; self._si.clear(); self._ab.setChecked(True); self.refresh()

    def _on_search(self):
        q = self._si.text().strip()
        if not q: QMessageBox.warning(self, "提示", "请输入学号"); return
        self._mode = 'single'; self._q = q; self._ab.setChecked(False); self.refresh()

    def _on_hide(self): self._hide = not self._hide; self._hb.setText("显示姓名" if self._hide else "隐藏姓名"); self.refresh()