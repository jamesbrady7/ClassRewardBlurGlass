# ============================================================
# 文件功能：主窗口——整个应用程序的"外壳"，组装所有Tab和工具栏
# 对应Tab：全部
# 依赖库：PyQt5, controller, view.tabs, view.style
# 使用方法：window = MainWindow(controller, config); window.show()
# ============================================================
import datetime
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QTabWidget, QMessageBox, QFileDialog, QInputDialog)
from controller.app_controller import AppController
from model.style_config import StyleConfig
from .tabs import RosterTab, GroupTab, RandomPickTab, BatchTab, ShopTab, HistoryTab, AnalysisTab
from .style import StyleSettingsDialog
from .style.animations import fade_in_window, fade_in

class MainWindow(QMainWindow):
    """主窗口：顶部标题栏 + 工具栏 + 统计条 + 7个Tab标签页"""
    def __init__(self, controller, config=None):
        super().__init__()
        self.ctrl = controller
        self.ctrl.subscribe(self._on_data_changed)
        if config is None:
            from model.style_config import get_config
            config = get_config()
        self._config = config
        self._init_ui()
        self._load_initial()
        self.apply_style()

    def apply_style(self):
        """应用当前样式配置（字体、颜色、窗口大小等）"""
        c = self._config
        self.setStyleSheet(c.generate_stylesheet())
        self.setMinimumSize(c.get('window_min_width',1100), c.get('window_min_height',750))
        self.resize(c.get('window_default_width',1600), c.get('window_default_height',1020))
        # 更新标题栏字体（标题用圆润展示体，正文沿用全局 token 字体）
        if hasattr(self, '_title_lbl') and self._title_lbl:
            self._apply_title_style()

    def _apply_title_style(self):
        """给大标题 + 版本徽章统一套用主题 token（标题大气、徽章低调）"""
        c = self._config
        ft = c.get('font_title', 26)
        tff = c.get('font_title_family', 'MiSans')
        self._title_lbl.setStyleSheet(
            f"font-family:'{tff}'; font-size:{ft}px; font-weight:bold;"
            f" color:{c.get('color_title_text','#1f2937')}; background:transparent;")
        bw = c.get('card_border_width', 1)
        self._ver_lbl.setStyleSheet(
            f"font-family:'{tff}'; font-size:{ft-12}px;"
            f" background:{c.get('color_tab_bg','#f0f3f9')};"
            f" border:{bw}px solid {c.get('color_card_border','#e6eaf2')};"
            f" border-radius:12px; padding:5px 14px;"
            f" color:{c.get('color_tab_text','#6b7484')};")

    def _init_ui(self):
        c = self._config
        self.setWindowTitle("班级激励助手 V3.16")
        self.setMinimumSize(c.get('window_min_width',1100), c.get('window_min_height',750))
        self.resize(c.get('window_default_width',1600), c.get('window_default_height',1020))
        central = QWidget(); self.setCentralWidget(central)
        ml = QVBoxLayout(central); ml.setSpacing(c.get('layout_main_spacing',12))
        margin = c.get('layout_content_margin',20)
        ml.setContentsMargins(margin,margin,margin,margin-5)

        # 标题栏（青绿渐变 logo + 大标题 + 低调版本徽章）
        tl = QHBoxLayout()
        logo = QLabel("★")
        logo.setFixedSize(44, 44); logo.setAlignment(Qt.AlignCenter)
        logo.setStyleSheet(
            "background:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #16b69b,stop:1 #0c8f7a);"
            "border-radius:12px;color:#ffffff;font-size:24px;font-weight:bold;")
        tl.addWidget(logo); tl.addSpacing(12)
        self._title_lbl = QLabel("班级激励助手")
        tl.addWidget(self._title_lbl); tl.addStretch()
        self._ver_lbl = QLabel("V3.16")
        tl.addWidget(self._ver_lbl); ml.addLayout(tl)
        self._apply_title_style()

        # 工具栏（班级切换 + 导出导入 + 样式设置）
        cb = QHBoxLayout(); self._cbl = QHBoxLayout(); cb.addLayout(self._cbl)
        nb = QPushButton("＋ 新班级", clicked=self._on_add_class)
        nb.setStyleSheet(c.accent_btn())
        cb.addWidget(nb)
        cb.addWidget(QPushButton("样式", clicked=lambda: StyleSettingsDialog(self._config,self,self).show()))
        cb.addStretch()
        cb.addWidget(QPushButton("导出", clicked=self._on_export))
        cb.addWidget(QPushButton("导入", clicked=self._on_import))
        ml.addLayout(cb)

        # 统计条
        sb = QHBoxLayout(); fs = c.get('font_stats',16)
        self._dl = QLabel("扣分达人(>3)"); self._dl.setStyleSheet(f"background:{c.get('color_deduct_label_bg')};color:white;border-radius:12px;padding:3px 10px;font-size:{fs}px;")
        sb.addWidget(self._dl); self._dll = QLabel("无"); sb.addWidget(self._dll); sb.addSpacing(20)
        self._el = QLabel("进步之星(+2)"); self._el.setStyleSheet(f"background:{c.get('color_earn_label_bg')};color:white;border-radius:12px;padding:3px 10px;font-size:{fs}px;")
        sb.addWidget(self._el); self._ell = QLabel("无"); sb.addWidget(self._ell); sb.addStretch()
        sb.addWidget(QLabel("每周更新")); ml.addLayout(sb)

        # 7个Tab
        self._tw = QTabWidget()
        self._tw.tabBar().setElideMode(Qt.ElideNone); self._tw.tabBar().setUsesScrollButtons(True)
        self.roster = RosterTab(self.ctrl,self); self._tw.addTab(self.roster,"花名册")
        self.group = GroupTab(self.ctrl,self); self._tw.addTab(self.group,"小组榜")
        self.draw = RandomPickTab(self.ctrl,self); self._tw.addTab(self.draw,"随机抽取")
        self.batch = BatchTab(self.ctrl,self); self._tw.addTab(self.batch,"批量操作")
        self.shop = ShopTab(self.ctrl,self); self._tw.addTab(self.shop,"积分商店")
        self.hist = HistoryTab(self.ctrl,self); self._tw.addTab(self.hist,"每日历史")
        self.analysis = AnalysisTab(self.ctrl,self); self._tw.addTab(self.analysis,"数据分析")
        self._tw.currentChanged.connect(self._on_tab_changed)
        ml.addWidget(self._tw, 1)

    def _on_tab_changed(self, idx):
        """切换 Tab：新页面淡入 + 刷新数据"""
        w = self._tw.widget(idx)
        if w is not None:
            fade_in(w, ms=200)
        self.refresh_all()

    def showEvent(self, event):
        """首次显示时做一次温柔的入场淡入"""
        super().showEvent(event)
        fade_in_window(self)

    def _load_initial(self):
        """加载班级按钮"""
        self._render_class_btns()

    def _on_data_changed(self):
        """数据变化后刷新"""
        self._render_class_btns(); self.refresh_all()

    def _render_class_btns(self):
        """渲染班级切换按钮"""
        while self._cbl.count():
            it = self._cbl.takeAt(0)
            if it.widget(): it.widget().deleteLater()
        for k in self.ctrl.app_data.classes:
            btn = QPushButton(k.name); btn.setCheckable(True); btn.setChecked(k.id==self.ctrl.current_class_id)
            btn.clicked.connect(lambda c,cid=k.id: (self.ctrl.set_current_class_id(cid),self._render_class_btns(),self.refresh_all()))
            self._cbl.addWidget(btn)

    def _on_add_class(self):
        name, ok = QInputDialog.getText(self, "新建班级", "班级名称:", text="新班级")
        if ok and name.strip(): self.ctrl.add_class(name.strip()); self._render_class_btns(); self.refresh_all()

    def _on_export(self):
        fp, _ = QFileDialog.getSaveFileName(self, "导出数据", f"备份_{datetime.date.today()}.json", "JSON (*.json)")
        if fp:
            if self.ctrl.export_data(fp): QMessageBox.information(self,"成功","导出成功")
            else: QMessageBox.warning(self,"失败","导出失败")

    def _on_import(self):
        fp, _ = QFileDialog.getOpenFileName(self, "导入数据", "", "JSON (*.json)")
        if fp:
            err = self.ctrl.import_data(fp)
            if err: QMessageBox.warning(self,"失败",err)
            else: QMessageBox.information(self,"成功","导入成功"); self._render_class_btns(); self.refresh_all()

    def refresh_all(self):
        """刷新所有Tab"""
        tabs = [self.roster, self.group, self.batch, self.shop, self.hist, self.analysis]
        for t in tabs: t.refresh()
        self._update_stats()

    def _update_stats(self):
        """更新扣分达人和进步之星（徽章色走主题 token）"""
        c = self._config
        dl, el = self.ctrl.get_weekly_stats()
        if dl:
            parts = [f"{d['student_id']}{d['name']}-{d['points']}" for d in dl]
            self._dll.setText(" ".join(parts))
            self._dll.setStyleSheet(f"background:{c.get('color_deduct_badge_bg','#ffd6d6')};border-radius:12px;padding:3px 8px;")
        else: self._dll.setText("无"); self._dll.setStyleSheet("")
        if el:
            parts = [f"{e['student_id']}{e['name']}{e['category']}+{e['diff']}" for e in el]
            self._ell.setText(" ".join(parts))
            self._ell.setStyleSheet(f"background:{c.get('color_earn_badge_bg','#c8efd9')};border-radius:12px;padding:3px 8px;")
        else: self._ell.setText("无"); self._ell.setStyleSheet("")