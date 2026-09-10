# ============================================================
# 文件功能：花名册Tab——学生列表管理界面
# 对应Tab：花名册
# 依赖库：PyQt5
# ============================================================
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QLineEdit, QScrollArea, QMessageBox
from view.widgets import StudentCardWidget
from view.dialogs import StudentDialog, ImportStudentDialog, HistoryDialog, BackpackDialog, MoveGroupDialog

class RosterTab(QWidget):
    """花名册Tab"""
    def __init__(self, controller, main_window, parent=None):
        super().__init__(parent); self.ctrl = controller; self.mw = main_window; self._build()

    @property
    def cfg(self): return self.mw._config

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(self.cfg.get('layout_main_spacing',12))
        tb = QHBoxLayout(); tl = QLabel("班级花名册"); tl.setStyleSheet(self.cfg.section_title_qss()); tb.addWidget(tl); tb.addStretch()
        ab = QPushButton("＋ 添加学生", clicked=lambda: StudentDialog(self.ctrl,self).exec_() and self.refresh())
        ab.setStyleSheet(self.cfg.accent_btn()); tb.addWidget(ab)
        tb.addWidget(QPushButton("导入学生", clicked=lambda: ImportStudentDialog(self.ctrl,self).exec_() and self.refresh()))
        lo.addLayout(tb)
        self._srch = QLineEdit(); self._srch.setPlaceholderText("搜索..."); self._srch.textChanged.connect(self.refresh); lo.addWidget(self._srch)
        sc = QScrollArea(); sc.setWidgetResizable(True)
        self._ct = QWidget(); self._cl = QVBoxLayout(self._ct); self._cl.setSpacing(self.cfg.get('card_list_spacing',8)); self._cl.addStretch()
        sc.setWidget(self._ct); lo.addWidget(sc,1)
        self._cnt = QLabel("  人数: 0/50  "); lo.addWidget(self._cnt)
        self._cnt.setStyleSheet(self.cfg.pill(self.cfg.get('color_tab_bg','#edf1f7'), self.cfg.get('color_tab_text','#6b7484'), radius=999, font_size=12))

    def refresh(self):
        cls = self.ctrl.current_class()
        if not cls: return
        while self._cl.count()>1:
            it = self._cl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        term = self._srch.text().lower()
        students = sorted(cls.students, key=lambda s: int(s.student_id) if s.student_id.isdigit() else 0)
        self._cl.setSpacing(self.cfg.get('card_list_spacing',8))
        for s in students:
            if term and term not in s.name.lower() and term not in s.student_id.lower(): continue
            g = cls.get_group_by_id(s.group_id) if s.group_id else None
            card = StudentCardWidget(s, self.cfg, g.name if g else '未分组')
            card.action_clicked.connect(self._on_action)
            self._cl.insertWidget(self._cl.count()-1, card)
        self._cnt.setText(f"人数: {len(cls.students)}/50")

    def _on_action(self, action, sid):
        cls = self.ctrl.current_class(); s = cls.get_student_by_id(sid) if cls else None
        if not s: return
        if action == 'undo': QMessageBox.information(self,"撤回",self.ctrl.undo_last_operation(sid)); self.refresh()
        elif action == 'history': HistoryDialog(s,self).exec_()
        elif action == 'backpack': BackpackDialog(s,self.ctrl,self).exec_(); self.refresh()
        elif action == 'move':
            if MoveGroupDialog(self.ctrl,s,self).exec_(): self.refresh()
        elif action == 'delete':
            if QMessageBox.Yes == QMessageBox.question(self,"确认",f"删除学生 {s.name}？",QMessageBox.Yes|QMessageBox.No):
                self.ctrl.delete_student(sid); self.refresh()