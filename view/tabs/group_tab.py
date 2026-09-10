# ============================================================
# 文件功能：小组榜Tab——小组排行榜和小组管理
# 对应Tab：小组榜
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QScrollArea, QInputDialog, QMessageBox
from view.widgets import GroupCardWidget
from view.dialogs import GroupDialog

class GroupTab(QWidget):
    """小组榜Tab：显示所有小组的排名、分数和成员"""
    def __init__(self, controller, main_window, parent=None):
        super().__init__(parent); self.ctrl = controller; self.mw = main_window; self._build()

    @property
    def cfg(self): return self.mw._config

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(self.cfg.get('layout_main_spacing',12))
        tb = QHBoxLayout(); tl = QLabel("小组排行榜"); tl.setStyleSheet(self.cfg.section_title_qss()); tb.addWidget(tl); tb.addStretch()
        ab = QPushButton("＋ 新建小组", clicked=lambda: GroupDialog(self.ctrl,self).exec_() and self.refresh())
        ab.setStyleSheet(self.cfg.accent_btn()); tb.addWidget(ab)
        lo.addLayout(tb)
        sc = QScrollArea(); sc.setWidgetResizable(True)
        self._ct = QWidget(); self._cl = QVBoxLayout(self._ct); self._cl.setSpacing(self.cfg.get('group_card_spacing',10)); self._cl.addStretch()
        sc.setWidget(self._ct); lo.addWidget(sc,1)

    def refresh(self):
        cls = self.ctrl.current_class()
        if not cls: return
        while self._cl.count()>1:
            it = self._cl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        gp = self.ctrl.compute_group_points()
        groups = sorted(cls.groups, key=lambda g: gp.get(g.id,0), reverse=True)
        self._cl.setSpacing(self.cfg.get('group_card_spacing',10))
        for idx, g in enumerate(groups):
            members = [{'student_id': s.student_id, 'name': s.name} for s in cls.students if s.group_id == g.id]
            card = GroupCardWidget(g, gp.get(g.id,0), members, self.cfg, idx+1 if idx<3 else 0)
            card.action_clicked.connect(self._on_action)
            card.rename_requested.connect(lambda gid: self._on_rename(gid))
            self._cl.insertWidget(self._cl.count()-1, card)

    def _on_action(self, action, gid):
        if action == 'addGroupPoints':
            v, ok = QInputDialog.getInt(self,"小组加分","加分值:",1,1,999)
            if ok: self.ctrl.add_direct_group_points(gid,v); self.refresh()
        elif action == 'subtractGroupPoints':
            v, ok = QInputDialog.getInt(self,"小组扣分","扣分值:",1,1,999)
            if ok: self.ctrl.subtract_direct_group_points(gid,v); self.refresh()
        elif action == 'deleteGroup':
            cls = self.ctrl.current_class()
            if cls and any(s.group_id==gid for s in cls.students):
                QMessageBox.warning(self,"提示","小组内还有学生，请先移走"); return
            if QMessageBox.Yes == QMessageBox.question(self,"确认","删除该小组？"):
                if self.ctrl.delete_group(gid): self.refresh()

    def _on_rename(self, gid):
        cls = self.ctrl.current_class(); g = cls.get_group_by_id(gid) if cls else None
        if g:
            name, ok = QInputDialog.getText(self,"重命名","新名称:",text=g.name)
            if ok and name.strip(): self.ctrl.rename_group(gid,name.strip()); self.refresh()