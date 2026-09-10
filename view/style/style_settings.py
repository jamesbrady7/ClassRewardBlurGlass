# ============================================================
# 文件功能：样式设置对话框——一个独立的"调色板"窗口
# 对应Tab：全部（通过主窗口"样式设置"按钮打开）
# 依赖库：PyQt5, model.style_config
# 使用方法：dialog = StyleSettingsDialog(config, main_window); dialog.show()
# ============================================================
from PyQt5.QtWidgets import (QDialog, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QScrollArea, QSlider, QSpinBox, QGroupBox, QGridLayout, QColorDialog, QMessageBox, QApplication)
from PyQt5.QtCore import Qt, pyqtSignal, QTimer
from PyQt5.QtGui import QColor, QFont
from model.style_config import StyleConfig, get_config

class ColorButton(QPushButton):
    """一个可以点击弹出颜色选择器的小色块按钮"""
    color_changed = pyqtSignal(str)
    def __init__(self, hex_color='#ffffff', parent=None):
        super().__init__(parent); self._color = hex_color
        self.setFixedSize(36,36); self.setCursor(Qt.PointingHandCursor)
        self.clicked.connect(self._pick); self._update()
    def _update(self):
        self.setStyleSheet(f"QPushButton{{background:{self._color};border:2px solid #999;border-radius:6px;}}")
    def _pick(self):
        c = QColorDialog.getColor(QColor(self._color), self, "选择颜色")
        if c.isValid(): self._color = c.name(); self._update(); self.color_changed.emit(self._color)

# 所有可调节的设置项（分组+项目列表）
ALL_SETTINGS = [
    ("花名册-字体",[('font_global','基础字体',8,48,1),('font_card_name','姓名',10,40,1),('font_card_id','学号',10,36,1),('font_card_group','小组标签',10,36,1),('font_card_points','分数',10,36,1)]),
    ("花名册-外观",[('card_height','卡片高度',50,200,5),('card_border_width','边框粗细',1,8,1),('card_radius','圆角',10,80,2),('icon_btn_size','按钮直径',28,80,4),('student_name_min_width','姓名宽度',50,200,5)]),
    ("花名册-颜色",[('color_card_bg','卡片背景'),('color_card_border','边框色'),('color_id_bg','学号牌背景'),('color_name_text','姓名色'),('color_group_tag_bg','小组标签背景'),('color_points_bg','分数背景'),('color_undo_bg','撤回按钮'),('color_delete_bg','删除按钮')]),
    ("小组榜-外观",[('group_btn_size','按钮直径',30,100,4),('group_card_spacing','卡片间距',2,40,2)]),
    ("顶部栏-字体",[('font_title','大标题',14,60,1),('font_section','板块标题',12,48,1),('font_stats','统计条',8,32,1)]),
    ("顶部栏-颜色",[('color_bg','窗口背景'),('color_title_text','标题色'),('color_deduct_label_bg','扣分标签'),('color_earn_label_bg','进步标签')]),
    ("全局-字体",[('font_button','按钮',8,40,1),('font_tab','标签页',8,40,1),('font_input','输入框',8,40,1),('font_groupbox','分组框',8,40,1)]),
    ("全局-边距",[('button_padding_h','按钮左右',6,50,2),('button_padding_v','按钮上下',2,30,2),('button_radius','按钮圆角',10,80,2),('tab_padding_h','标签左右',10,60,2),('tab_padding_v','标签上下',4,30,2),('tab_radius','标签圆角',10,60,2),('input_padding_h','输入框左右',8,50,2),('input_padding_v','输入框上下',2,30,2),('input_radius','输入框圆角',10,60,2),('tab_margin_h','标签间距',0,20,1),('tab_min_width','标签最小宽',50,200,5)]),
    ("全局-颜色",[('color_button_bg','按钮背景'),('color_button_border','按钮边框'),('color_button_text','按钮文字'),('color_button_hover','悬停'),('color_accent_bg','强调按钮'),('color_tab_bg','标签背景'),('color_tab_selected_bg','选中标签'),('color_tab_text','标签文字'),('color_input_bg','输入框背景'),('color_input_border','输入框边框'),('color_input_focus_border','焦点边框')]),
    ("图表大小",[('chart_radar_size','雷达图',200,600,20),('chart_trend_size','趋势图',200,600,20)]),
    ("布局间距",[('layout_main_spacing','区域间距',4,40,2),('layout_content_margin','四周留白',8,40,2),('card_list_spacing','卡片间距',2,30,2)]),
    ("商店/历史字体",[('shop_reward_font','奖品名',10,32,1),('shop_cat_font','等级标签',10,28,1),('font_history','历史记录',8,30,1)]),
    ("图表字体",[('font_analysis_radar_cat','雷达维度',8,20,1),('font_analysis_radar_val','雷达分数',6,18,1),('font_analysis_trend_point','趋势总分',8,24,1),('font_analysis_trend_detail','趋势明细',5,14,1),('font_analysis_trend_date','趋势日期',5,14,1),('font_analysis_trend_axis','趋势坐标',6,16,1)]),
]

class StyleSettingsDialog(QDialog):
    """样式设置工具箱（非模态窗口，调整后主窗口立即变化）"""
    def __init__(self, config, main_window, parent=None):
        super().__init__(parent); self._config = config; self._mw = main_window
        self._sliders = {}; self._colors = {}; self._spins = {}
        self._init = True  # 初始化期间禁止触发刷新
        self._timer = QTimer(self); self._timer.setSingleShot(True); self._timer.setInterval(200)
        self._timer.timeout.connect(self._do_refresh)
        self.setWindowTitle("样式设置 V3.16"); self.setMinimumSize(800,650); self.resize(850,750)
        self.setWindowFlags(Qt.Window|Qt.WindowMinMaxButtonsHint); self._build(); self._init = False

    def _safe(self, k, d=50):
        v = self._config.get(k); return v if v is not None else d

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(6)
        lo.addWidget(QLabel("样式设置 V3.16 — 拖动滑块立即生效"))
        br = QHBoxLayout(); br.addStretch()
        rb = QPushButton("恢复默认"); rb.clicked.connect(self._on_reset); br.addWidget(rb)
        sb = QPushButton("永久保存"); sb.setStyleSheet(get_config().accent_btn()); sb.clicked.connect(self._on_save); br.addWidget(sb)
        lo.addLayout(br)
        sc = QScrollArea(); sc.setWidgetResizable(True); ct = QWidget(); cl = QVBoxLayout(ct); cl.setSpacing(10)
        for gt, items in ALL_SETTINGS:
            if any(len(it)==5 for it in items):
                g = QGroupBox(gt); gl = QGridLayout(g); gl.setSpacing(4)
                for idx, (k, lb, mn, mx, st) in enumerate(items):
                    v = self._safe(k,(mn+mx)//2)
                    ll = QLabel(lb); ll.setWordWrap(True); ll.setStyleSheet("font-size:13px;")
                    vl = QLabel(str(v)); vl.setFixedWidth(50); vl.setStyleSheet(f"font-size:13px;font-weight:bold;color:{self._config.get('color_section_title','#e07aa0')};")
                    sl = QSlider(Qt.Horizontal); sl.setRange(mn,mx); sl.setValue(v); sl.setSingleStep(st); sl.setFixedWidth(180)
                    sl.valueChanged.connect(lambda val,k=k,vl=vl: self._on_slider(k,val,vl))
                    sp = QSpinBox(); sp.setRange(mn,mx); sp.setValue(v); sp.setSingleStep(st); sp.setFixedWidth(65)
                    sp.valueChanged.connect(lambda val,k=k,sl=sl: sl.setValue(val))
                    self._sliders[k]=sl; self._spins[k]=sp
                    gl.addWidget(ll,idx,0); gl.addWidget(vl,idx,1); gl.addWidget(sl,idx,2); gl.addWidget(sp,idx,3)
                cl.addWidget(g)
            else:
                g = QGroupBox(gt); gl = QGridLayout(g); gl.setSpacing(4); cols=4
                for idx,(k,lb) in enumerate(items):
                    rw=idx//cols; cll=(idx%cols)*2
                    cb = ColorButton(self._config.get(k)or'#cccccc'); cb.color_changed.connect(lambda h,k=k:self._on_color(k,h)); self._colors[k]=cb
                    ll=QLabel(lb); ll.setStyleSheet("font-size:12px;")
                    inner=QHBoxLayout(); inner.setSpacing(4); inner.addWidget(cb); inner.addWidget(ll); inner.addStretch()
                    iw=QWidget(); iw.setLayout(inner); gl.addWidget(iw,rw,cll)
                cl.addWidget(g)
        cl.addStretch(); sc.setWidget(ct); lo.addWidget(sc,1)

    def _on_slider(self, k, v, vl):
        if self._init: return
        self._config.set(k,v); vl.setText(str(v)); self._apply_qss(); self._timer.start()

    def _on_color(self, k, c):
        if self._init: return
        self._config.set(k,c); self._apply_qss(); self._timer.start()

    def _apply_qss(self):
        if self._mw:
            self._mw.setStyleSheet(self._config.generate_stylesheet())
            app = QApplication.instance()
            if app: app.setFont(QFont(self._config.get('font_family','Microsoft YaHei'), self._config.get('font_global',10)))
            self._mw.resize(self._config.get('window_default_width',1600),self._config.get('window_default_height',1020))
            self._mw.repaint()

    def _do_refresh(self):
        if self._mw: self._mw.apply_style(); self._mw.refresh_all(); self._mw.repaint()

    def _on_save(self):
        self._config.save(); self._do_refresh()
        QMessageBox.information(self,"已保存","样式已保存到 style_config.json"); self.accept()

    def _on_reset(self):
        if QMessageBox.Yes == QMessageBox.question(self,"确认","恢复默认？",QMessageBox.Yes|QMessageBox.No):
            self._config.reset_to_defaults()
            for k,sl in self._sliders.items():
                v=self._config.get(k)
                if v: sl.blockSignals(True); sl.setValue(v); sl.blockSignals(False)
            for k,sp in self._spins.items():
                v=self._config.get(k)
                if v: sp.blockSignals(True); sp.setValue(v); sp.blockSignals(False)
            for k,cb in self._colors.items():
                v=self._config.get(k)
                if v: cb._color=v; cb._update()
            self._apply_qss(); self._do_refresh()