# ============================================================
# 文件功能：积分商店Tab——奖品兑换和盲盒抽奖
# 对应Tab：积分商店
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QComboBox, QLineEdit, QScrollArea, QFrame, QMessageBox
from view.dialogs import RewardDialog, HistoryDialog, BackpackDialog

class ShopTab(QWidget):
    """积分商店：选择学生，浏览奖品，用积分兑换"""
    def __init__(self, ctrl, mw, parent=None):
        super().__init__(parent); self.ctrl = ctrl; self.mw = mw; self._cat = 'all'; self._build()

    @property
    def cfg(self): return self.mw._config

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(12); tl = QLabel("积分商店"); tl.setStyleSheet(self.cfg.section_title_qss()); lo.addWidget(tl)

        # 学生选择栏
        sr = QHBoxLayout(); self._ss = QLineEdit(); self._ss.setPlaceholderText("搜索学生...")
        self._ss.textChanged.connect(self.refresh); sr.addWidget(self._ss)
        self._cb = QComboBox(); self._cb.currentIndexChanged.connect(self._on_stu); sr.addWidget(self._cb)
        self._sl = QLabel("未选择"); sr.addWidget(self._sl)
        for t, h in [("撤回", self._on_undo), ("历史", self._on_hist), ("背包", self._on_back)]:
            sr.addWidget(QPushButton(t, clicked=h))
        sr.addStretch(); lo.addLayout(sr)

        # 分类筛选按钮
        cr = QHBoxLayout(); cr.setSpacing(6); self._cbs = {}
        for c, la in [('all','全部'), ('普通','普通'), ('稀有','稀有'), ('史诗','史诗'), ('传说','传说')]:
            b = QPushButton(la); b.setCheckable(True); b.setChecked(c=='all')
            b.clicked.connect(lambda cc, c=c: self._on_cat(c)); self._cbs[c] = b; cr.addWidget(b)
        cr.addStretch(); lo.addLayout(cr)

        # 奖品列表
        sv = QScrollArea(); sv.setWidgetResizable(True)
        self._rc = QWidget(); self._rl = QVBoxLayout(self._rc); self._rl.setSpacing(5); self._rl.addStretch()
        sv.setWidget(self._rc); lo.addWidget(sv, 1)

        # 新增奖品按钮 + 盲盒区
        ab = QPushButton("＋ 新增奖励", clicked=lambda: RewardDialog(self.ctrl, self).exec_() and self.refresh())
        ab.setStyleSheet(self.cfg.accent_btn()); lo.addWidget(ab)
        bf = QFrame(); bf.setStyleSheet(f"QFrame{{background:{self.cfg.get('color_blind_bg','#fcf3e0')};border:2px dashed {self.cfg.get('color_accent_bg','#0fa88f')};border-radius:16px;}}")
        bl = QHBoxLayout(bf); bl.addWidget(QLabel("🎁 盲盒券 (10分) · 随机抽取奖励")); bl.addStretch()
        bl.addWidget(QPushButton("兑换", clicked=self._on_blind, styleSheet=self.cfg.accent_btn()))
        lo.addWidget(bf)

    def refresh(self):
        cls = self.ctrl.current_class()
        if not cls: return
        cs = self._cb.currentData(); self._cb.blockSignals(True); self._cb.clear(); self._cb.addItem("--选择学生--", "")
        term = self._ss.text().lower()
        for s in sorted(cls.students, key=lambda x: int(x.student_id) if x.student_id.isdigit() else 0):
            if term and term not in s.name.lower() and term not in s.student_id.lower(): continue
            self._cb.addItem(f"{s.student_id} {s.name} (可用:{s.available_points})", s.id)
        if cs:
            idx = self._cb.findData(cs)
            if idx >= 0: self._cb.setCurrentIndex(idx)
        self._cb.blockSignals(False); self._on_stu()

        while self._rl.count() > 1:
            it = self._rl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        rws = [r for r in cls.rewards if self._cat == 'all' or r.category == self._cat]
        srf, scf = self.cfg.get('shop_reward_font', 14), self.cfg.get('shop_cat_font', 12)
        cm = {'普通': ('#d8ecff', '#2f6b9e'), '稀有': ('#e8defa', '#6b4fa0'),
              '史诗': ('#ffe9b8', '#9c7418'), '传说': ('#ffd9d9', '#a13d3d')}
        for r in rws:
            if r.blind_box_excluded: continue
            row = QHBoxLayout()
            bg, tc = cm.get(r.category, ('#e6ecf5', '#3d5a80'))
            cl = QLabel(r.category); cl.setStyleSheet(f"background:{bg};color:{tc};border-radius:15px;padding:2px 10px;font-weight:bold;font-size:{scf}px;")
            row.addWidget(cl)
            nl = QLabel(f"{r.name} ({r.cost}分)"); nl.setStyleSheet(f"color:{self.cfg.get('color_name_text','#3e9a88')};font-size:{srf}px;"); row.addWidget(nl); row.addStretch()
            row.addWidget(QPushButton("兑换", clicked=lambda c, rid=r.id: self._on_redeem(rid)))
            db = QPushButton("🗑"); db.setFixedSize(30,30); db.clicked.connect(lambda c2, rid=r.id: self._on_del(rid)); row.addWidget(db)
            cw = QWidget(); cw.setLayout(row); self._rl.insertWidget(self._rl.count() - 1, cw)

    def _on_stu(self):
        sid = self._cb.currentData()
        if not sid: self._sl.setText("未选择"); return
        cls = self.ctrl.current_class()
        if cls and (s := cls.get_student_by_id(sid)): self._sl.setText(f"{s.student_id} {s.name} (可用:{s.available_points})")

    def _on_cat(self, c): self._cat = c; self.refresh()

    def _on_redeem(self, rid):
        sid = self._cb.currentData()
        if not sid: QMessageBox.warning(self, "提示", "请先选择学生"); return
        err = self.ctrl.redeem_reward(sid, rid)
        if err: QMessageBox.warning(self, "失败", err)
        else: self.refresh(); self.mw.refresh_all()

    def _on_blind(self):
        sid = self._cb.currentData()
        if not sid: QMessageBox.warning(self, "提示", "请先选择学生"); return
        msg = self.ctrl.buy_blind_box(sid)
        if msg: QMessageBox.information(self, "盲盒", msg); self.refresh(); self.mw.refresh_all()

    def _on_undo(self):
        sid = self._cb.currentData()
        if not sid: QMessageBox.warning(self, "提示", "请先选择学生"); return
        QMessageBox.information(self, "撤回", self.ctrl.undo_last_operation(sid)); self.refresh(); self.mw.refresh_all()

    def _on_hist(self):
        sid = self._cb.currentData(); cls = self.ctrl.current_class()
        if sid and cls and (s := cls.get_student_by_id(sid)): HistoryDialog(s, self).exec_()

    def _on_back(self):
        sid = self._cb.currentData(); cls = self.ctrl.current_class()
        if sid and cls and (s := cls.get_student_by_id(sid)): BackpackDialog(s, self.ctrl, self).exec_(); self.refresh(); self.mw.refresh_all()

    def _on_del(self, rid):
        if QMessageBox.Yes == QMessageBox.question(self, "确认", "删除该奖励？"): self.ctrl.delete_reward(rid); self.refresh()