# ============================================================
# 文件功能：随机抽取Tab——加权随机抽取学生或小组
# 对应Tab：随机抽取
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QSpinBox, QScrollArea, QGroupBox, QMessageBox
from PyQt5.QtCore import Qt
from model.entities import CATEGORY_DIMENSIONS
from view.style.animations import fade_in

class RandomPickTab(QWidget):
    """随机抽取：抽学生或小组，用6个维度标签加减分"""
    def __init__(self, ctrl, mw, parent=None):
        super().__init__(parent); self.ctrl = ctrl; self.mw = mw
        self._cat = ''; self._ps = []; self._pg = []; self._build()

    @property
    def cfg(self): return self.mw._config

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(12); tl = QLabel("随机抽取"); tl.setStyleSheet(self.cfg.section_title_qss()); lo.addWidget(tl)
        # 抽取控制行
        pr = QHBoxLayout()
        self._sc = QSpinBox(); self._sc.setRange(1,50); self._sc.setValue(3)
        pr.addWidget(QLabel("抽")); pr.addWidget(self._sc); pr.addWidget(QLabel("名学生"))
        sb = QPushButton("抽取学生", clicked=self._on_students); sb.setStyleSheet(self.cfg.accent_btn()); pr.addWidget(sb)
        self._gc = QSpinBox(); self._gc.setRange(1,20); self._gc.setValue(1)
        pr.addWidget(QLabel("抽")); pr.addWidget(self._gc); pr.addWidget(QLabel("个小组"))
        pr.addWidget(QPushButton("抽取小组", clicked=self._on_groups))
        pr.addStretch(); lo.addLayout(pr)

        # 结果区域
        self._ra = QScrollArea(); self._ra.setWidgetResizable(True)
        self._rc = QWidget(); self._rl = QVBoxLayout(self._rc)
        self._rl.setSpacing(5); self._rl.addStretch()
        self._ra.setWidget(self._rc); self._ra.setMinimumHeight(self.cfg.get('draw_result_min_height',250))
        lo.addWidget(self._ra, 1)

        # 分值输入
        br = QHBoxLayout(); br.addWidget(QLabel("分值:"))
        self._pv = QSpinBox(); self._pv.setRange(1,999); self._pv.setValue(1)
        br.addWidget(self._pv); br.addStretch(); lo.addLayout(br)

        # 维度选择
        cg = QGroupBox("操作维度"); cl = QHBoxLayout(); self._cbs = {}
        for cat in CATEGORY_DIMENSIONS:
            btn = QPushButton(cat); btn.setCheckable(True)
            btn.clicked.connect(lambda c,cat=cat: self._on_cat(cat)); self._cbs[cat]=btn; cl.addWidget(btn)
        cl.addStretch(); cg.setLayout(cl); lo.addWidget(cg)

    def _on_cat(self, cat):
        self._cat = cat
        accent = self.cfg.get('color_accent_bg', '#0fa88f')
        for k,b in self._cbs.items():
            b.setChecked(k==cat)
            b.setStyleSheet(f"QPushButton{{background:{accent};color:white;}}" if k==cat else "")

    def _on_students(self):
        pk = self.ctrl.random_pick_students(self._sc.value()); self._ps=pk; self._pg=[]; self._show_s(pk)

    def _on_groups(self):
        pk = self.ctrl.random_pick_groups(self._gc.value()); self._pg=pk; self._ps=[]; self._show_g(pk)

    def _clear(self):
        while self._rl.count()>1:
            it=self._rl.takeAt(0)
            if it.widget(): it.widget().deleteLater()

    def _mk_row(self, label_text, plus_cb, minus_cb):
        """生成一行结果：药丸名 + 加分/扣分圆形按钮，返回可加入布局的容器"""
        c = self.cfg
        r = QHBoxLayout(); r.setSpacing(8)
        lb = QLabel(label_text)
        lb.setStyleSheet(c.pill(c.get('color_card_bg','#ffffff'), c.get('color_name_text','#1f2937'),
                                border=c.get('color_card_border','#e6eaf2'), font_size=13, padding='3px 12px'))
        r.addWidget(lb); r.addStretch()
        a = QPushButton("+"); a.setFixedSize(28, 28); a.setStyleSheet(c.icon_btn(c.get('color_accent_bg','#0fa88f'), 'white', 28, font_size=18))
        a.clicked.connect(plus_cb); r.addWidget(a)
        b = QPushButton("−"); b.setFixedSize(28, 28); b.setStyleSheet(c.icon_btn(c.get('color_backpack_bg','#fde9f0'), c.get('color_backpack_text','#c2487a'), 28, font_size=18))
        b.clicked.connect(minus_cb); r.addWidget(b)
        cw = QWidget(); cw.setLayout(r); return cw

    def _show_s(self, pk):
        self._clear()
        if not pk: self._rl.insertWidget(0,QLabel("—"))
        for i, s in enumerate(pk):
            cw = self._mk_row(
                f"{s['student_id']} {s['name']}（可用 {s['available']} 分）",
                lambda c, sid=s['id']: self._on_sp(sid, True),
                lambda c, sid=s['id']: self._on_sp(sid, False))
            self._rl.insertWidget(self._rl.count()-1, cw)
            fade_in(cw, delay=60*i)   # 逐行错峰淡入

    def _show_g(self, pk):
        self._clear()
        if not pk: self._rl.insertWidget(0,QLabel("—"))
        for i, g in enumerate(pk):
            cw = self._mk_row(
                f"🏆 {g['name']}",
                lambda c, gid=g['id']: self._on_gp(gid, True),
                lambda c, gid=g['id']: self._on_gp(gid, False))
            self._rl.insertWidget(self._rl.count()-1, cw)
            fade_in(cw, delay=60*i)

    def _on_sp(self, sid, add):
        if not self._cat: QMessageBox.warning(self,"提示","请先选择维度"); return
        self.ctrl.point_change(sid,self._pv.value(),add,self._cat)
        if self._ps:
            cls=self.ctrl.current_class()
            self._ps=[{'id':s.id,'student_id':s.student_id,'name':s.name,'available':s.available_points} for ps in self._ps if (s:=cls.get_student_by_id(ps['id']))]
            self._show_s(self._ps)
        self.mw.refresh_all()

    def _on_gp(self, gid, add):
        if add: self.ctrl.add_direct_group_points(gid,self._pv.value())
        else: self.ctrl.subtract_direct_group_points(gid,self._pv.value())
        self.mw.refresh_all()