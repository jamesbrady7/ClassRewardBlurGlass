# ============================================================
# 文件功能：批量操作Tab——勾选多名学生，一次性加减分
# 对应Tab：批量操作
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QSpinBox, QScrollArea, QGridLayout, QGroupBox, QMessageBox)
from model.entities import CATEGORY_DIMENSIONS

class BatchTab(QWidget):
    """批量操作：选中多名学生，一次性加减分"""
    def __init__(self, ctrl, mw, parent=None):
        super().__init__(parent); self.ctrl = ctrl; self.mw = mw
        self._ids = set(); self._cat = ''; self._build()

    @property
    def cfg(self): return self.mw._config

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(12); tl = QLabel("批量操作"); tl.setStyleSheet(self.cfg.section_title_qss()); lo.addWidget(tl)

        # 学生头像网格
        sv = QScrollArea(); sv.setWidgetResizable(True)
        self._bc = QWidget(); self._bl = QGridLayout(self._bc); self._bl.setSpacing(6)
        sv.setWidget(self._bc); sv.setMaximumHeight(self.cfg.get('batch_area_max_height',200)); lo.addWidget(sv)

        # 控制栏
        cr = QHBoxLayout()
        cr.addWidget(QPushButton("全选", clicked=self._on_all))
        cr.addWidget(QPushButton("取消全选", clicked=lambda: (self._ids.clear(), self.refresh())))
        cr.addWidget(QLabel("分值:"))
        self._ps = QSpinBox(); self._ps.setRange(1,999); self._ps.setValue(1); self._ps.setFixedWidth(80); cr.addWidget(self._ps)
        pb = QPushButton("加分", clicked=lambda: self._op(True)); pb.setStyleSheet(self.cfg.accent_btn()); cr.addWidget(pb)
        db = QPushButton("扣分", clicked=lambda: self._op(False))
        db.setStyleSheet("QPushButton{background:#fceae8;border:1px solid #e8c4c0;color:#c84a3e;font-weight:600;border-radius:10px;padding:8px 16px;}"
                         "QPushButton:hover{background:#f6d8d4;}QPushButton:pressed{background:#f0c9c4;}")
        cr.addWidget(db)
        self._ml = QLabel(""); cr.addWidget(self._ml); cr.addStretch(); lo.addLayout(cr)

        # 维度选择标签
        cg = QGroupBox("操作分类"); cl = QHBoxLayout(); self._cbs = {}
        for cat in CATEGORY_DIMENSIONS:
            b = QPushButton(cat); b.setCheckable(True)
            b.clicked.connect(lambda c,cat=cat: self._sc(cat)); self._cbs[cat]=b; cl.addWidget(b)
        cl.addStretch(); cg.setLayout(cl); lo.addWidget(cg); lo.addStretch()

    def refresh(self):
        cls = self.ctrl.current_class()
        if not cls: return
        while self._bl.count():
            it = self._bl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        st = sorted(cls.students, key=lambda s: int(s.student_id) if s.student_id.isdigit() else 0)
        bw, bh = self.cfg.get('batch_badge_width',60), self.cfg.get('batch_badge_height',52)
        cols, bf = self.cfg.get('batch_badge_cols',10), self.cfg.get('batch_badge_font',11)
        c = self.cfg
        for idx, s in enumerate(st):
            btn = QPushButton(f"{s.student_id}\n{s.name[:3]}"); btn.setCheckable(True)
            btn.setChecked(s.id in self._ids); btn.setFixedSize(bw,bh)
            btn.setStyleSheet(
                f"QPushButton{{background:{c.get('color_tab_bg','#ffe9f1')};"
                f"border:2px solid {c.get('color_card_border','#c9e8dc')};"
                f"border-radius:15px;font-size:{bf}px;color:{c.get('color_tab_text','#e08bad')};}}"
                f" QPushButton:checked{{background:{c.get('color_accent_bg','#0fa88f')};color:white;}}"
                f" QPushButton:hover{{background:{c.get('color_earn_badge_bg','#e2f5ec')};border-color:{c.get('color_accent_bg','#0fa88f')};}}")
            btn.toggled.connect(lambda c,sid=s.id: self._ids.add(sid) if c else self._ids.discard(sid))
            self._bl.addWidget(btn, idx//cols, idx%cols)

    def _on_all(self):
        cls = self.ctrl.current_class()
        if cls: self._ids = {s.id for s in cls.students}; self.refresh()

    def _sc(self, cat):
        self._cat = cat
        accent = self.cfg.get('color_accent_bg', '#0fa88f')
        for k,b in self._cbs.items(): b.setChecked(k==cat); b.setStyleSheet(f"QPushButton{{background:{accent};color:white;}}" if k==cat else "")

    def _op(self, add):
        if not self._ids: QMessageBox.warning(self,"提示","请选择学生"); return
        if not self._cat: QMessageBox.warning(self,"提示","请选择分类"); return
        sc,fc = self.ctrl.batch_point_operation(list(self._ids), self._ps.value(), add, self._cat)
        self._ids.clear(); self.refresh(); self._ml.setText(f"成功:{sc} 失败:{fc}"); self.mw.refresh_all()