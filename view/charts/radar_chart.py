# ============================================================
# 文件功能：雷达图组件——六边形雷达图展示6维度得分
# 对应Tab：数据分析
# 依赖库：PyQt5, math
# ============================================================
import math
from PyQt5.QtWidgets import QWidget, QSizePolicy
from PyQt5.QtCore import Qt, QRectF, QPointF
from PyQt5.QtGui import QPainter, QPen, QBrush, QColor, QFont, QPainterPath
from model.entities import CATEGORY_DIMENSIONS

FIXED_RADAR_MAX = 20

class RadarChartWidget(QWidget):
    """六边形雷达图：课堂/考试/听写/背诵/作业/纪律 6个维度的得分"""
    def __init__(self, config=None, parent=None):
        super().__init__(parent)
        self._scores = {}; self._config = config
        self.setMinimumSize(300,300)

    def draw_chart(self, scores):
        self._scores = scores; self.update()

    def _font(self, key, default, bold=False):
        size = self._config.get(key, default) if self._config else default
        fam = self._config.get('font_family', 'Microsoft YaHei') if self._config else 'Microsoft YaHei'
        return QFont(fam, size, QFont.Bold if bold else QFont.Normal)

    def paintEvent(self, event):
        if not self._scores: return
        p = QPainter(self); p.setRenderHint(QPainter.Antialiasing)
        w, h = self.width(), self.height(); sz = min(w,h)
        cx, cy = w/2, h/2; r = sz*0.34; n = 6
        step = (math.pi*2)/n; start = -math.pi/2

        for layer in range(1,6):
            rr = (r/5)*layer; path = QPainterPath()
            for i in range(n):
                a = start+i*step; x,y = cx+rr*math.cos(a),cy+rr*math.sin(a)
                if i==0: path.moveTo(x,y)
                else: path.lineTo(x,y)
            path.closeSubpath()
            p.setPen(QPen(QColor('#bfe8de'if layer==5 else'#e8eee9'),1.5 if layer==5 else 0.8))
            p.setBrush(Qt.NoBrush); p.drawPath(path)

        for i in range(n):
            a = start+i*step; p.setPen(QPen(QColor('#e8eee9'),0.6))
            p.drawLine(QPointF(cx,cy),QPointF(cx+r*math.cos(a),cy+r*math.sin(a)))

        values = [self._scores.get(cat,0) for cat in CATEGORY_DIMENSIONS]
        norms = [min(abs(v)/FIXED_RADAR_MAX,1.0) for v in values]
        path = QPainterPath()
        for i in range(n):
            a = start+i*step; rr = norms[i]*r
            x,y = cx+rr*math.cos(a),cy+rr*math.sin(a)
            if i==0: path.moveTo(x,y)
            else: path.lineTo(x,y)
        path.closeSubpath()

        total = sum(values)
        if total>0: fc,sc = QColor(15,168,143,45), QColor('#0e8c77')
        elif total<0: fc,sc = QColor(244,155,155,85), QColor('#e3686b')
        else: fc,sc = QColor(180,200,190,80), QColor('#8aa399')
        p.setBrush(QBrush(fc)); p.setPen(QPen(sc,2)); p.drawPath(path)

        for i in range(n):
            a = start+i*step; rr = norms[i]*r
            p.setBrush(QBrush(sc)); p.setPen(QPen(QColor('white'),1.5))
            p.drawEllipse(QPointF(cx+rr*math.cos(a),cy+rr*math.sin(a)),4,4)

        mv,mi = float('inf'),-1
        for i,v in enumerate(values):
            if v<mv: mv,mi = v,i

        cf = self._font('font_analysis_radar_cat',10,True)
        vf = self._font('font_analysis_radar_val',8)
        lr = r+28
        for i,cat in enumerate(CATEGORY_DIMENSIONS):
            a = start+i*step; x = cx+lr*math.cos(a); y = cy+lr*math.sin(a)
            val = values[i]
            p.setFont(cf); p.setPen(QPen(QColor('#e3686b'if i==mi else'#0e8c77')))
            p.drawText(QRectF(x-40,y-20,80,38),Qt.AlignCenter,cat)
            vs = f'+{val}'if val>0 else(str(val)if val<0 else'0')
            p.setFont(vf)
            p.setPen(QPen(QColor('#e3686b')if i==mi else(QColor('#0e8c77')if val>0 else QColor('#e3686b')if val<0 else QColor('#9fb3ac'))))
            p.drawText(QRectF(x-40,y+1,80,38),Qt.AlignCenter,vs)

        if mi>=0:
            ma = start+mi*step; mr = norms[mi]*r
            mx,my = cx+mr*math.cos(ma),cy+mr*math.sin(ma)
            p.setBrush(Qt.NoBrush); p.setPen(QPen(QColor('#e3686b'),3))
            p.drawEllipse(QPointF(mx,my),8,8)
            p.setBrush(QBrush(QColor('#e3686b'))); p.setPen(Qt.NoPen)
            p.drawEllipse(QPointF(mx,my),3,3)

        fam = self._config.get('font_family', 'Microsoft YaHei') if self._config else 'Microsoft YaHei'
        p.setFont(QFont(fam,12,QFont.Bold))
        p.setPen(QPen(QColor('#0e8c77')if total>0 else QColor('#e3686b')if total<0 else QColor('#8aa399')))
        txt = f'+{total}'if total>0 else(str(total)if total<0 else'0')
        p.drawText(QRectF(cx-40,cy-18,80,40),Qt.AlignCenter,txt)
        p.end()