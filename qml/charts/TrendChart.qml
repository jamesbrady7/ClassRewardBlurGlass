import QtQuick

// 学习趋势折线图（Canvas 绘制）：**每天**的净分（加分 − 扣分），按真实日期比例排布。
//
// 刻度：固定 −5..+8（一天的量程，用户给定单日加分≤8、扣分≤5），一学期都不用改。
//       个别超常数据（如批量补录）会让轴自动扩到 5 的整数倍，**绝不夹平**。
//
// 其他要点：
// · **没数据也要有刻度**：学生还没加分时，网格/刻度/日期轴照常画出来。
// · **X 轴（0 线）实线加粗**；其余所有平行于它的刻度线一律虚线。
// · 首点不贴 Y 轴：留 _leadX 的空隙，避免和原点重合。
// · 点某个数据点 → 浮出小气泡，列出当天的明细（"课堂 +2 / 纪律 −1"）。
Canvas {
    id: root

    property var transactions: []
    property real classMaxDaily: 0
    property real classMinDaily: 0
    property real viewWidth: 400

    // 首点与 Y 轴之间的空隙
    readonly property int _leadX: 18
    // 气泡：当前选中的数据点（-1 = 未选）
    property int selIdx: -1

    // ⚠️ 别写成 ceil(v/5)*5 —— 那样 v=8 时会被抬到 10（多出一整个空档）。
    //    只有**真的超过** 8 / 低于 −5 时才扩档。
    readonly property real topVal: classMaxDaily > 8
                                    ? Math.ceil(classMaxDaily / 5) * 5 : 8
    readonly property real bottomVal: classMinDaily < -5
                                      ? Math.floor(classMinDaily / 5) * 5 : -5

    property real pxPerDay: Math.max(14, Math.min(48, (viewWidth - 54) / Math.max(1, _spanDays())))
    function _spanDays() {
        var ds = _days()
        if (ds.length < 2) return 1
        return ds[ds.length - 1].ord - ds[0].ord + 1
    }

    // 按自然日聚合（**不累计**），并记下当天每个维度的明细，供气泡显示
    function _days() {
        var map = {}
        var arr = root.transactions
        for (var i = 0; i < arr.length; i++) {
            var t = arr[i]
            if (t.type !== "earn" && t.type !== "deduct") continue
            var d = new Date(t.ts * 1000)
            var ord = Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000)
            var e = map[ord]
            if (!e) {
                e = { ord: ord, val: 0, date: (d.getMonth() + 1) + "/" + d.getDate(), items: [] }
                map[ord] = e
            }
            var delta = (t.type === "earn" ? t.points : -t.points)
            e.val += delta
            e.items.push({ cat: (t.desc || "其他"), val: delta })
        }
        var keys = Object.keys(map).map(Number).sort(function(a, b) { return a - b })
        var out = []
        for (var k = 0; k < keys.length; k++) out.push(map[keys[k]])
        return out
    }

    property real contentWidth: {
        var ds = _days()
        if (!ds.length) return 40 + 24
        var span = ds[ds.length - 1].ord - ds[0].ord + 1
        return 40 + _leadX + span * root.pxPerDay + 14
    }

    onTransactionsChanged: { selIdx = -1; requestPaint() }
    onClassMaxDailyChanged: requestPaint()
    onClassMinDailyChanged: requestPaint()
    Component.onCompleted: requestPaint()

    // 几何量随绘制一起算，命中测试要用同一套
    readonly property int padL: 40
    readonly property int padT: 26
    readonly property int padB: 28

    function _geom() {
        var ch = height - padT - padB
        var yRange = topVal - bottomVal
        return { ch: ch, yRange: yRange,
                 x0: padL + _leadX,
                 py: function(v) {
                     var c = Math.max(bottomVal, Math.min(topVal, v))
                     return padT + ch - ((c - bottomVal) / yRange) * ch
                 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            var ds = root._days()
            if (!ds.length) { root.selIdx = -1; root.requestPaint(); return }
            var g = root._geom()
            var best = -1, bestD = 999
            for (var i = 0; i < ds.length; i++) {
                var x = g.x0 + (ds[i].ord - ds[0].ord) * root.pxPerDay
                var y = g.py(ds[i].val)
                var d = Math.sqrt((m.x - x) * (m.x - x) + (m.y - y) * (m.y - y))
                if (d < bestD) { bestD = d; best = i }
            }
            // 点空了就收起气泡
            root.selIdx = bestD <= 18 ? (root.selIdx === best ? -1 : best) : -1
            root.requestPaint()
        }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var days = root._days()
        var g = root._geom()
        var ch = g.ch, yRange = g.yRange
        var cw = days.length ? (days[days.length - 1].ord - days[0].ord) * root.pxPerDay : 0
        var x0 = g.x0

        // ── 其余刻度线：虚线 ──
        ctx.strokeStyle = "#dfe9e4"; ctx.lineWidth = 0.7
        ctx.setLineDash([3, 4])
        ctx.fillStyle = "#6b7d75"; ctx.font = "8px 'MiSans'"
        ctx.textAlign = "right"; ctx.textBaseline = "middle"
        for (var yv = Math.ceil(root.bottomVal / 2) * 2; yv <= root.topVal; yv += 2) {
            if (Math.abs(yv) < 0.001) continue          // 0 线 = X 轴，单独画
            var gy = g.py(yv)
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(x0 + cw + 8, gy); ctx.stroke()
            ctx.fillText(yv > 0 ? "+" + yv : String(yv), padL - 6, gy)
        }
        ctx.setLineDash([])

        // ── X 轴（0 线）：实线、加粗 ──
        ctx.strokeStyle = "#9fd8c6"; ctx.lineWidth = 1.8
        ctx.beginPath(); ctx.moveTo(padL, g.py(0)); ctx.lineTo(x0 + cw + 8, g.py(0)); ctx.stroke()
        ctx.fillStyle = "#6b7d75"; ctx.textAlign = "right"; ctx.textBaseline = "middle"
        ctx.fillText("0", padL - 6, g.py(0))

        // 没数据时到这儿就结束 —— 刻度/坐标轴已经画好了
        if (!days.length) return

        function px(i) { return x0 + (days[i].ord - days[0].ord) * root.pxPerDay }
        var pts = []
        for (var i = 0; i < days.length; i++) pts.push({ x: px(i), y: g.py(days[i].val), d: days[i] })

        // 面积填充（线到 X 轴之间）
        if (pts.length > 1) {
            var grad = ctx.createLinearGradient(0, padT, 0, padT + ch)
            grad.addColorStop(0, "rgba(14,140,119,0.20)")
            grad.addColorStop(1, "rgba(14,140,119,0.02)")
            ctx.beginPath()
            ctx.moveTo(pts[0].x, g.py(0))
            for (i = 0; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
            ctx.lineTo(pts[pts.length - 1].x, g.py(0))
            ctx.closePath()
            ctx.fillStyle = grad; ctx.fill()
        }

        // 折线
        ctx.strokeStyle = "#0e8c77"; ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (i = 0; i < pts.length; i++) {
            if (i) ctx.lineTo(pts[i].x, pts[i].y)
            else ctx.moveTo(pts[i].x, pts[i].y)
        }
        ctx.stroke()

        // 数据点 + 值 + 日期
        // ⚠️ 标签要**防重叠**：数据跨几十天时每天只有十几像素，标签会糊成一团。
        //    离上一个已画标签太近就跳过（点本身照画）。
        ctx.textAlign = "center"
        var lastValX = -999, lastDateX = -999
        for (i = 0; i < pts.length; i++) {
            var neg = pts[i].d.val < 0
            ctx.beginPath(); ctx.arc(pts[i].x, pts[i].y, i === root.selIdx ? 5 : 4, 0, Math.PI * 2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.strokeStyle = neg ? "#e3686b" : "#0e8c77"; ctx.lineWidth = 2; ctx.stroke()

            if (pts[i].x - lastValX >= 22) {
                ctx.font = "bold 9px 'MiSans'"
                ctx.fillStyle = neg ? "#e3686b" : "#0e8c77"
                ctx.fillText(pts[i].d.val > 0 ? "+" + pts[i].d.val : String(pts[i].d.val), pts[i].x, pts[i].y - 10)
                lastValX = pts[i].x
            }
            if (pts[i].x - lastDateX >= 34) {
                ctx.font = "8px 'MiSans'"
                ctx.fillStyle = "#6b7d75"
                ctx.fillText(pts[i].d.date, pts[i].x, padT + ch + 13)
                lastDateX = pts[i].x
            }
        }

        // ── 气泡：当天的明细 ──
        if (root.selIdx >= 0 && root.selIdx < pts.length) {
            var d = pts[root.selIdx].d
            var lines = []
            // 同维度合并（同一天可能点了好几次）
            var agg = {}
            for (i = 0; i < d.items.length; i++) agg[d.items[i].cat] = (agg[d.items[i].cat] || 0) + d.items[i].val
            for (var k in agg) lines.push(k + (agg[k] > 0 ? " +" : " ") + agg[k] + " 分")
            if (!lines.length) lines.push("无记录")

            ctx.font = "9px 'MiSans'"
            var bw = 56, th = 13
            for (i = 0; i < lines.length; i++) bw = Math.max(bw, ctx.measureText(lines[i]).width + 18)
            var bh = lines.length * th + 12

            var bx = pts[root.selIdx].x + 12
            var by = pts[root.selIdx].y - bh - 12
            if (bx + bw > width - 4) bx = pts[root.selIdx].x - bw - 12
            if (by < 2) by = pts[root.selIdx].y + 14

            ctx.fillStyle = "rgba(38,44,58,0.92)"
            ctx.beginPath()
            var rr = 7, r2 = bx + bw, b2 = by + bh
            ctx.moveTo(bx + rr, by)
            ctx.lineTo(r2 - rr, by); ctx.quadraticCurveTo(r2, by, r2, by + rr)
            ctx.lineTo(r2, b2 - rr); ctx.quadraticCurveTo(r2, b2, r2 - rr, b2)
            ctx.lineTo(bx + rr, b2); ctx.quadraticCurveTo(bx, b2, bx, b2 - rr)
            ctx.lineTo(bx, by + rr); ctx.quadraticCurveTo(bx, by, bx + rr, by)
            ctx.closePath(); ctx.fill()

            ctx.fillStyle = "#ffffff"; ctx.font = "9px 'MiSans'"
            ctx.textAlign = "left"; ctx.textBaseline = "middle"
            for (i = 0; i < lines.length; i++)
                ctx.fillText(lines[i], bx + 9, by + 9 + i * th)
        }
    }
}
