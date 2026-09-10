# ============================================================
# 文件功能：管理整个程序的外观配置（颜色、字体、大小等）
# 对应Tab：全部（通过"样式设置"工具箱调整）
# 依赖库：json, os, sys（Python内置）
# 使用方法：config = get_config(); 字号 = config.get('font_title')
#
# 【设计 Token 化】所有视觉要素都收敛在这里：
#   DEFAULTS             —— 主题唯一的「设计 token」（色板 / 字号 / 圆角 / 间距）
#   generate_stylesheet  —— 由 token 生成全局 QSS
#   pill()/icon_btn()/accent_btn()/card_frame() —— 可复用的组件样式助手
#   各控件不要硬编码颜色，一律通过 config.get('color_xxx') 取 token。
#
# 设计语言（2026-09 重构）：
#   「清新 · 高级」—— 明亮轻快的校园风，但不廉价：
#     · 近白底色 + 白卡片，细边框（1px）代替粗色框
#     · 主色为清脆的青绿色（翡翠），支持色用柔和低饱和的粉/蓝/紫/杏
#     · 字体层级克制：正文 13 / 次要 12 / 强调 600 字重
#     · 圆角 8~14，克制；药丸标签、圆形图标按钮
# ============================================================
import json, os, sys


def _asset_dir():
    """定位 assets/icons：源码运行时=项目根/assets/icons；打包后=exe目录/assets/icons"""
    if getattr(sys, 'frozen', False):
        base = os.path.dirname(sys.executable)
    else:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, 'assets', 'icons')


def _shade(hex_color, factor):
    """把 #RRGGBB 颜色按 factor 调整（>1 变亮，<1 变暗），返回新 #RRGGBB。

    用于自动生成 hover / pressed 反馈色，保证与主题联动。
    """
    h = (hex_color or '').lstrip('#')
    if len(h) != 6:
        return hex_color
    try:
        r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    except ValueError:
        return hex_color
    r = min(255, max(0, int(r * factor)))
    g = min(255, max(0, int(g * factor)))
    b = min(255, max(0, int(b * factor)))
    return f'#{r:02x}{g:02x}{b:02x}'


class StyleConfig:
    """外观配置管理器。像一个"调色板+刻度尺"，控制界面所有视觉效果。"""

    DEFAULTS = {
        # ---------------- 窗口 ----------------
        'window_default_width': 1600,
        'window_default_height': 1020,
        'window_min_width': 1100,
        'window_min_height': 750,

        # ---------------- 字体（层级克制） ----------------
        'font_family': 'MiSans',             # 正文字体（内置 assets/fonts 加载）
        'font_title_family': 'MiSans',       # 标题字重走 Bold/Semibold
        'font_global': 13, 'font_title': 26, 'font_section': 16, 'font_tab': 14,
        'font_button': 13, 'font_input': 14, 'font_card_name': 15,
        'font_card_id': 13, 'font_card_group': 12, 'font_card_points': 14,
        'font_groupbox': 14, 'font_stats': 13, 'font_history': 14,
        'font_analysis_header': 16, 'font_analysis_label': 13,
        'font_analysis_radar_cat': 11, 'font_analysis_radar_val': 10,
        'font_analysis_trend_point': 10, 'font_analysis_trend_detail': 7,
        'font_analysis_trend_date': 9, 'font_analysis_trend_axis': 9,
        'shop_reward_font': 14, 'shop_cat_font': 12, 'blind_font': 13,

        # ---------------- 组件尺寸 ----------------
        'card_height': 68, 'card_radius': 14, 'card_border_width': 1,
        'icon_btn_size': 38, 'group_btn_size': 34, 'group_card_spacing': 12,
        'batch_badge_width': 52, 'batch_badge_height': 48, 'batch_badge_cols': 12,
        'batch_badge_font': 11, 'draw_result_min_height': 240,
        'batch_area_max_height': 200, 'student_name_min_width': 90,
        # 按钮/边距
        'button_padding_h': 16, 'button_padding_v': 8, 'button_radius': 10,
        'tab_padding_h': 20, 'tab_padding_v': 9, 'tab_radius': 10,
        'tab_margin_h': 3, 'tab_min_width': 70,
        'input_padding_h': 12, 'input_padding_v': 8, 'input_radius': 8,
        'section_title_padding_h': 14, 'section_title_padding_v': 6,
        'section_title_radius': 12,
        # 图表尺寸
        'chart_radar_size': 340, 'chart_trend_size': 300,
        'radar_max_value': 20, 'trend_y_steps': 4,
        # 间距
        'layout_main_spacing': 14, 'layout_content_margin': 24,
        'layout_section_spacing': 16, 'card_list_spacing': 10,
        'group_list_spacing': 10,

        # ---------------- 颜色（#RRGGBB）「清新·高级」 ----------------
        # 底色与卡片（页面背景为清晰浅灰蓝，与白色卡片拉开对比，边界分明）
        'color_bg': '#edf1f7', 'color_card_bg': '#ffffff',
        'color_card_border': '#dfe5ee',
        # 主按钮（次级：白底细边）与主色（翡翠青绿）
        'color_button_bg': '#ffffff', 'color_button_border': '#d9dfe9',
        'color_button_text': '#2b3340', 'color_button_hover': '#f0f4f9',
        'color_button_pressed': '#e6ecf4',
        'color_accent_bg': '#0fa88f', 'color_accent_border': '#0c8f7a',
        'color_accent_text': '#ffffff',
        # 标签页（未选中透明，选中白色胶囊）
        'color_tab_bg': '#f0f3f9', 'color_tab_selected_bg': '#ffffff',
        'color_tab_selected_text': '#0e8c77', 'color_tab_text': '#6b7484',
        # 输入框
        'color_input_bg': '#ffffff', 'color_input_border': '#d9dfe9',
        'color_input_focus_border': '#0fa88f',
        # 文字
        'color_group_bg': '#ffffff', 'color_group_border': '#e6eaf2',
        'color_group_title_text': '#1f2937', 'color_title_text': '#1f2937',
        'color_section_title': '#3d4757', 'color_name_text': '#1f2937',
        # 学生卡片徽章（柔和低饱和 tint）
        'color_id_bg': '#e8f4f1', 'color_id_text': '#0b7a66',
        'color_group_tag_bg': '#e9f1fb', 'color_group_tag_border': '#d4e2f5',
        'color_group_tag_text': '#3369b5',
        'color_points_bg': '#fdf3e7', 'color_points_border': '#f3e2c6',
        'color_points_text': '#9a6a0a',
        # 学生操作按钮
        'color_undo_bg': '#efeafb', 'color_undo_text': '#6746c9',
        'color_history_bg': '#fcf3e0', 'color_history_text': '#9a6a0a',
        'color_backpack_bg': '#fde9f0', 'color_backpack_text': '#c2487a',
        'color_move_bg': '#e8f1fd', 'color_move_text': '#3369b5',
        'color_delete_bg': '#fceae8', 'color_delete_text': '#c84a3e',
        # 扣分 / 进步
        'color_deduct_label_bg': '#ff7a70', 'color_deduct_label_text': '#ffffff',
        'color_earn_label_bg': '#22b489', 'color_earn_label_text': '#ffffff',
        'color_deduct_badge_bg': '#fce8e6', 'color_earn_badge_bg': '#e2f5ec',
        # 盲盒
        'color_blind_bg': '#fcf3e0',
        # 小组榜前三名（tint 略深，与普通卡片区分开）
        'color_rank1_bg': '#fff4da', 'color_rank1_border': '#e8b44f',
        'color_rank2_bg': '#edf0f6', 'color_rank2_border': '#c9d1de',
        'color_rank3_bg': '#fbe9d8', 'color_rank3_border': '#ddab7f',
        # 滚动条
        'color_scrollbar_bg': '#edf0f6', 'color_scrollbar_handle': '#c9d1de',
    }

    def __init__(self, config_path=None):
        if config_path is None:
            exe_dir = os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__))
            config_path = os.path.join(exe_dir, '..', 'style_config.json')
        self._path = config_path
        self._data = {}
        self.load()

    def load(self):
        """从 JSON 文件读取配置，缺失的用默认值补充"""
        if os.path.exists(self._path):
            try:
                with open(self._path, 'r', encoding='utf-8') as f:
                    self._data = json.load(f)
            except: self._data = {}
        for k, v in self.DEFAULTS.items():
            if k not in self._data: self._data[k] = v

    def save(self):
        """保存配置到 JSON 文件"""
        try:
            with open(self._path, 'w', encoding='utf-8') as f:
                json.dump(self._data, f, ensure_ascii=False, indent=2)
        except: pass

    def reset_to_defaults(self):
        """恢复出厂默认样式"""
        self._data = dict(self.DEFAULTS); self.save()

    def get(self, key, default=None):
        """获取某个配置项的值"""
        return self._data.get(key, default)

    def set(self, key, value):
        """修改某个配置项的值"""
        self._data[key] = value

    def all_data(self):
        """返回所有配置的副本"""
        return dict(self._data)

    # ============================================================
    # 组件样式助手：控件用它保持与主题一致，不再各自硬编码颜色
    # ============================================================

    def pill(self, bg, color, radius=999, border=None, border_width=None,
             font_size=None, padding='3px 12px'):
        """圆角药丸标签（学号徽章、小组标签、分数牌等）"""
        s = f"background:{bg};color:{color};border-radius:{radius}px;padding:{padding};"
        if border:
            bw = border_width or self.get('card_border_width', 1)
            s += f"border:{bw}px solid {border};"
        if font_size:
            s += f"font-size:{font_size}px;"
        return s

    def icon_btn(self, bg, color, size, radius=None, font_size=None):
        """圆形图标按钮（柔和底色 + 悬停加深反馈）"""
        r = radius if radius is not None else size // 2
        fs = font_size if font_size is not None else size - 16
        return (f"QPushButton{{border:none;background:{bg};color:{color};border-radius:{r}px;"
                f"min-width:{size}px;min-height:{size}px;max-width:{size}px;max-height:{size}px;font-size:{fs}px;}}"
                f" QPushButton:hover{{background:{_shade(bg, 0.92)};}}"
                f" QPushButton:pressed{{background:{_shade(bg, 0.84)};}}")

    def accent_btn(self, text_color=None):
        """主强调按钮（翡翠青绿），用于各页主操作与对话框确认"""
        a = self.get('color_accent_bg', '#0fa88f')
        b = self.get('color_accent_border', '#0c8f7a')
        tc = text_color or self.get('color_accent_text', '#ffffff')
        bw = self.get('card_border_width', 1)
        r = self.get('button_radius', 10)
        pad = f"{self.get('button_padding_v',8)}px {self.get('button_padding_h',16)}px"
        return (f"QPushButton{{background:{a};border:{bw}px solid {b};color:{tc};border-radius:{r}px;"
                f"padding:{pad};font-weight:600;}}"
                f" QPushButton:hover{{background:{_shade(a, 0.90)};}}"
                f" QPushButton:pressed{{background:{_shade(a, 0.80)};}}")

    def section_title_qss(self):
        """板块标题样式（16px / 600 / 深灰蓝 + 左侧翡翠强调条），用于各 Tab 顶部标题"""
        accent = self.get('color_accent_bg', '#0fa88f')
        return (f"font-weight:600;font-size:{self.get('font_section', 16)}px;"
                f"color:{self.get('color_section_title', '#3d4757')};"
                f"border-left:4px solid {accent};padding-left:10px;")

    def card_frame(self, bg=None, border=None, radius=None, padding='8px'):
        """卡片外框：白底带极淡上亮下暗渐变 + 下缘微深，营造「浮起」层次（非死白平板）"""
        bg = bg or self.get('color_card_bg', '#ffffff')
        border = border or self.get('color_card_border', '#dfe5ee')
        radius = radius or self.get('card_radius', 14)
        bw = self.get('card_border_width', 1)
        if bg.lower() == '#ffffff':
            fill = (f"qlineargradient(x1:0,y1:0,x2:0,y2:1,"
                    f"stop:0 #ffffff, stop:1 {_shade(bg, 0.975)})")
        else:
            fill = bg
        return (f"QFrame{{background:{fill};border:{bw}px solid {border};"
                f"border-bottom:{bw+1}px solid {_shade(border, 0.92)};"
                f"border-radius:{radius}px;padding:{padding};}}"
                f" QFrame:hover{{border-color:{self.get('color_accent_bg', '#0fa88f')};}}")

    def generate_stylesheet(self):
        """根据当前配置生成 Qt 样式表（QSS），这是控制界面外观的核心"""
        d = self._data
        bw = d['card_border_width']
        ff = d.get('font_family', 'MiSans')
        # 定制箭头图标（绝对路径，正斜杠，避免 CWD 依赖）
        ic = os.path.join(_asset_dir(), 'spinner-up.svg').replace(os.sep, '/')
        id_ = os.path.join(_asset_dir(), 'spinner-down.svg').replace(os.sep, '/')
        ic_h = os.path.join(_asset_dir(), 'spinner-up-hover.svg').replace(os.sep, '/')
        id_h = os.path.join(_asset_dir(), 'spinner-down-hover.svg').replace(os.sep, '/')
        cb = os.path.join(_asset_dir(), 'combo-down.svg').replace(os.sep, '/')
        return f"""
QMainWindow, QDialog {{
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                stop:0 {_shade(d['color_bg'], 1.02)}, stop:1 {_shade(d['color_bg'], 0.97)});
}}
QWidget {{ font-family: "{ff}"; color: {d['color_name_text']}; }}

/* ---- 按钮：白底细边次级态 ---- */
QPushButton {{
    background: {d['color_button_bg']}; border: {bw}px solid {d['color_button_border']};
    border-radius: {d['button_radius']}px; padding: {d['button_padding_v']}px {d['button_padding_h']}px;
    color: {d['color_button_text']}; font-weight: 600; font-size: {d['font_button']}px;
}}
QPushButton:hover {{ background: {d['color_button_hover']}; border-color: {d['color_accent_bg']}; color: {d['color_id_text']}; }}
QPushButton:pressed {{ background: {d['color_button_pressed']}; }}
QPushButton:checked {{ background: {d['color_earn_badge_bg']}; border-color: {d['color_accent_bg']}; color: {d['color_id_text']}; }}
QPushButton:disabled {{ background: {d['color_bg']}; color: #b3bac6; border-color: {d['color_card_border']}; }}
QPushButton:focus {{ outline: none; border-color: {d['color_accent_bg']}; }}

/* ---- 输入框 ---- */
QLineEdit, QComboBox, QSpinBox {{
    border: {bw}px solid {d['color_input_border']}; border-radius: {d['input_radius']}px;
    padding: {d['input_padding_v']}px {d['input_padding_h']}px; font-size: {d['font_input']}px;
    background: {d['color_input_bg']}; color: {d['color_name_text']};
    selection-background-color: #cdeee7;
}}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus {{ border-color: {d['color_input_focus_border']}; background: #ffffff; }}
QComboBox::drop-down {{ border: none; width: 26px; }}
QComboBox QAbstractItemView {{
    border: {bw}px solid {d['color_input_border']}; border-radius: 8px;
    background: {d['color_input_bg']}; font-size: {d['font_input']}px; color: {d['color_name_text']};
    selection-background-color: {d['color_earn_badge_bg']}; selection-color: {d['color_id_text']};
}}

/* ---- 数字输入框 / 下拉框：定制箭头按钮（告别原生难看样式）---- */
QSpinBox::up-button, QDoubleSpinBox::up-button,
QSpinBox::down-button, QDoubleSpinBox::down-button {{
    border: none; background: transparent; width: 22px;
    border-radius: 6px; margin: 2px;
}}
QSpinBox::up-button:hover, QDoubleSpinBox::up-button:hover,
QSpinBox::down-button:hover, QDoubleSpinBox::down-button:hover {{ background: #e6ecf3; }}
QSpinBox::up-button:pressed, QDoubleSpinBox::up-button:pressed,
QSpinBox::down-button:pressed, QDoubleSpinBox::down-button:pressed {{ background: #d8e0ea; }}
QSpinBox::up-arrow, QDoubleSpinBox::up-arrow {{ image: url({ic}); width: 8px; height: 8px; }}
QSpinBox::down-arrow, QDoubleSpinBox::down-arrow {{ image: url({id_}); width: 8px; height: 8px; }}
QSpinBox::up-button:hover QSpinBox::up-arrow {{ image: url({ic_h}); }}
QSpinBox::down-button:hover QSpinBox::down-arrow {{ image: url({id_h}); }}
QComboBox::down-arrow {{ image: url({cb}); width: 10px; height: 10px; }}

/* ---- 标签页：白色胶囊选中 ---- */
QTabWidget::pane {{ border: none; background: transparent; }}
QTabBar::tab {{
    background: transparent; border: {bw}px solid transparent; border-radius: {d['tab_radius']}px;
    padding: {d['tab_padding_v']}px {d['tab_padding_h']}px;
    color: {d['color_tab_text']}; font-weight: 600; font-size: {d['font_tab']}px;
    margin: {d['tab_margin_h']}px 2px;
}}
QTabBar::tab:hover {{ background: {d['color_tab_bg']}; color: {d['color_name_text']}; }}
QTabBar::tab:selected {{
    background: {d['color_tab_selected_bg']}; color: {d['color_tab_selected_text']};
    border-color: {d['color_card_border']};
}}

/* ---- 滚动区域 / 滚动条（细） ---- */
QScrollArea {{ border: none; background: transparent; border-radius: 12px; }}
QScrollBar:vertical {{ border: none; background: {d['color_scrollbar_bg']}; width: 10px; border-radius: 5px; margin: 2px; }}
QScrollBar::handle:vertical {{ background: {d['color_scrollbar_handle']}; border-radius: 5px; min-height: 40px; }}
QScrollBar::handle:vertical:hover {{ background: {_shade(d['color_scrollbar_handle'], 0.85)}; }}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0px; }}
QScrollBar:horizontal {{ border: none; background: {d['color_scrollbar_bg']}; height: 10px; border-radius: 5px; margin: 2px; }}
QScrollBar::handle:horizontal {{ background: {d['color_scrollbar_handle']}; border-radius: 5px; min-width: 40px; }}
QScrollBar::handle:horizontal:hover {{ background: {_shade(d['color_scrollbar_handle'], 0.85)}; }}
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {{ width: 0px; }}

/* ---- 分组框 ---- */
QGroupBox {{
    border: {bw}px solid {d['color_group_border']}; border-radius: 12px;
    background: transparent; margin-top: 12px; padding-top: 22px;
    font-weight: 600; color: {d['color_section_title']}; font-size: {d['font_groupbox']}px;
}}
QGroupBox::title {{ subcontrol-origin: margin; left: 16px; padding: 0 8px; }}

/* ---- 其它 ---- */
QToolTip {{ background: #ffffff; color: {d['color_name_text']}; border: {bw}px solid {d['color_input_border']}; border-radius: 6px; padding: 4px 8px; }}
QCheckBox, QRadioButton {{ font-size: {d['font_input']}px; }}
"""


_config_instance = None  # 单例模式，全局只有一个配置对象

def get_config():
    """获取全局唯一的配置管理器"""
    global _config_instance
    if _config_instance is None: _config_instance = StyleConfig()
    return _config_instance
