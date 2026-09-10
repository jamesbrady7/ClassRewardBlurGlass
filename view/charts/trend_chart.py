# ============================================================
# 文件功能：趋势折线图组件——显示学生分数随时间变化的折线
# 对应Tab：数据分析
# 依赖库：PyQt5, datetime, collections
# 使用方法：trend = TrendChartWidget(config=c); trend.draw_chart(transactions)
# ============================================================
from collections import defaultdict
from PyQt5.QtWidgets import QWidget, QSizePolicy
from PyQt5.QtCore import Qt, QRectF, QPointF
from PyQt5.QtGui import QPainter, QPen, QBrush, QColor, QFont, QLinearGradient, QPainterPath

# Y轴范围：+10到-5
TOP, BOTTOM, X_STEP = 10, -5, 80

class TrendChartWidget(QWidget):
    """学习趋势折线图。横轴是日期，纵轴是分数。点击数据点可查看各维度加分明细。"""
    def __init__(self, config=None, parent=None):
        super().__init__(parent)
        self._transactions = []
        self._config = config
        self._clicked_points = set()  # 记录哪些数据点被点击展开了
        self._hit_areas = []  # 存储可点击区域 [(x,y,data_index)]
        self.setMinimumSize(300, 300)
        self.setCursor(Qt.PointingHandCursor)  # 手型光标提示可点击

    def draw_chart(self, transactions):
        self._transactions = transactions; self.update()

    def _font(self, key, default_size, bold=False):
        size = self._config.get(key, default_size) if self._config else default_size
        fam = self._config.get('font_family', 'Microsoft YaHei') if self._config else 'Microsoft YaHei'
        return QFont(fam, size, QFont.Bold if bold else QFont.Normal)

    def paintEvent(self, event):
        if not self._transactions:
            p = QPainter(self); p.setFont(self._font('font_analysis_label',12))
            p.setPen(QPen(QColor('#9fb3ac'))); p.drawText(self.rect(),Qt.AlignCenter,'暂无加减分记录'); p.end(); return

        score_tx = [t for t in self._transactions if t.type in ('earn','deduct')]
        if not score_tx:
            p = QPainter(self); p.setFont(self._font('font_analysis_label',12))
            p.setPen(QPen(QColor('#9fb3ac'))); p.drawText(self.rect(),Qt.AlignCenter,'暂无加减分记录'); p.end(); return

        # 按日期分组
        import datetime
        dg = defaultdict(lambda:{'total':0,'dims':{}})
        for t in score_tx:
            dt = datetime.datetime.fromtimestamp(t.timestamp)
            dk = dt.strftime('%m/%d')
            delta = t.points if t.type=='earn' else -t.points
            dg[dk]['total'] += delta
            desc = (t.description or '').strip()
            if desc:
                if desc not in dg[dk]['dims']: dg[dk]['dims'][desc] = 0
                dg[dk]['dims'][desc] += delta

        dates = sorted(dg.keys(), key=lambda dk: next((t.timestamp for t in score_tx if datetime.datetime.fromtimestamp(t.timestamp).strftime('%m/%d')==dk),0))
        if not dates: return

        totals = [dg[d]['total'] for d in dates]
        y_range = TOP - BOTTOM
        clamp = [max(BOTTOM, min(TOP, v)) for v in totals]

        painter = QPainter(self); painter.setRenderHint(QPainter.Antialiasing)
        w, h = self.width(), self.height()
        pad = {'top':55,'right':15,'bottom':40,'left':40}
        cw = max(X_STEP*(len(dates)-1)+80, w-pad['left']-pad['right'])
        ch = h - pad['top'] - pad['bottom']

        # 数据点
        points=[]
        for idx, d in enumerate(dates):
            x = pad['left']+30 + idx*X_STEP
            y = pad['top']+ch-((clamp[idx]-BOTTOM)/y_range)*ch
            points.append({'x':x,'y':y,'val':totals[idx],'date':d,'dims':dg[d]['dims']})

        # Y轴网格
        af = self._font('font_analysis_trend_axis',8)
        for yv in [10,5,0,-5]:
            y = pad['top']+ch-((yv-BOTTOM)/y_range)*ch
            painter.setPen(QPen(QColor('#e8eee9'),0.5))
            painter.drawLine(QPointF(pad['left'],y), QPointF(pad['left']+cw,y))
            painter.setFont(af); painter.setPen(QPen(QColor('#6b7d75')))
            t = f'+{yv}' if yv>0 else (str(yv) if yv<0 else '0')
            painter.drawText(QRectF(0,y-8,pad['left']-5,16), Qt.AlignRight|Qt.AlignVCenter, t)

        zero_y = pad['top']+ch-((0-BOTTOM)/y_range)*ch
        painter.setPen(QPen(QColor('#b9e2d4'),1.5,Qt.DashLine))
        painter.drawLine(QPointF(pad['left'],zero_y), QPointF(pad['left']+cw,zero_y))

        # 折线
        path = QPainterPath()
        for idx, p in enumerate(points):
            if idx==0: path.moveTo(p['x'],p['y'])
            else: path.lineTo(p['x'],p['y'])
        painter.setPen(QPen(QColor('#0e8c77'),2.5)); painter.setBrush(Qt.NoBrush); painter.drawPath(path)

        # 面积填充
        if len(points)>=2:
            ap=QPainterPath(); ap.moveTo(points[0]['x'],zero_y)
            for p in points: ap.lineTo(p['x'],p['y'])
            ap.lineTo(points[-1]['x'],zero_y); ap.closeSubpath()
            g=QLinearGradient(0,pad['top'],0,pad['top']+ch); g.setColorAt(0,QColor(14,140,119,55)); g.setColorAt(1,QColor(14,140,119,5))
            painter.setPen(Qt.NoPen); painter.setBrush(QBrush(g)); painter.drawPath(ap)

        pf = self._font('font_analysis_trend_point',10,True)
        df = self._font('font_analysis_trend_detail',7)
        dtf = self._font('font_analysis_trend_date',7)

        # 记录可点击区域
        self._hit_areas = []
        for idx, p in enumerate(points):
            painter.setBrush(QBrush(QColor('white')))
            painter.setPen(QPen(QColor('#0e8c77')if p['val']>=0 else QColor('#e3686b'),2.5))
            painter.drawEllipse(QPointF(p['x'],p['y']),5,5)
            self._hit_areas.append((p['x'], p['y'], idx))
            ly = p['y']-12

            # 用不同背景色标记被点击展开的数据点
            expanded = idx in self._clicked_points
            if expanded:
                # 展开状态：在总分上方显示各维度加分明细
                dk = [k for k,v in p['dims'].items() if v!=0]
                if dk:
                    parts = [f"{k}{'+'+str(p['dims'][k]) if p['dims'][k]>0 else str(p['dims'][k])}" for k in dk]
                    ds = ' | '.join(parts)
                    if len(ds) > 40: ds = ds[:39] + '…'
                    painter.setFont(df); painter.setPen(QPen(QColor('#e3686b')))
                    # 明细标签在总分上方，留有足够空间
                    painter.drawText(QRectF(p['x']-90, ly-90, 180, 50), Qt.AlignCenter, ds)

            # 总分（始终显示）
            ts = f'+{p["val"]}' if p['val']>=0 else str(p['val'])
            painter.setFont(pf)
            painter.setPen(QPen(QColor('#0e8c77')if p['val']>=0 else QColor('#e3686b')))
            painter.drawText(QRectF(p['x']-45, ly-40, 90, 50), Qt.AlignCenter, ts)
            # 日期
            painter.setFont(dtf); painter.setPen(QPen(QColor('#6b7d75')))
            painter.drawText(QRectF(p['x']-30, zero_y+8, 60, 14), Qt.AlignCenter, p['date'])
        painter.end()

    def event(self, e):
        """
        重写 event() 方法来捕获鼠标点击。
        用 event() 而不是 mousePressEvent，因为 QScrollArea 会拦截子控件的 mousePressEvent。
        QEvent.MouseButtonPress 在 event() 中仍然可以收到。
        """
        from PyQt5.QtCore import QEvent
        if e.type() == QEvent.MouseButtonPress:
            pos = e.pos() if hasattr(e, 'pos') else e.localPos().toPoint()
            for x, y, idx in self._hit_areas:
                dx = pos.x() - x
                dy = pos.y() - y
                if dx * dx + dy * dy <= 400:
                    if idx in self._clicked_points:
                        self._clicked_points.discard(idx)
                    else:
                        self._clicked_points.add(idx)
                    self.update()
                    return True
        return super().event(e)
