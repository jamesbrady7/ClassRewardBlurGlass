import QtQuick

// 学习趋势折线图（Canvas 绘制）：**每天**的净分（加分 − 扣分），按真实日期比例排布。
//
// 刻度：默认 −5..+8（一天的量程，用户给定单日加分≤8、扣分≤5），一学期都不用改；
//       个别超常数据（如批量补录）会扩到 5 的整数倍，**绝不夹平**。
//
// 其他要点：
// · **没数据也要有刻度**：学生还没加分时，网格/刻度/坐标轴照常画出来。
// · **X 轴（0 线）实线加粗**；其余所有平行于它的刻度线一律虚线，
//   且**一律画到画布最右端**（只有一个日期时也不会缩成一小截）。
// · 折线从 **0 点起笔**（首日的前一天，落在 0 线上）——这个起点**不标分数、不画点**。
// · **每个数据点上方都标分数**（不再按间距跳过）。
// · 点某个数据点 → 浮出同色气泡（带小尖尖指向该点），列出当天明细。
Canvas {
    id: root

    property var transactions: []
    property real classMaxDaily: 0
    property real classMinDaily: 0
    property real viewWidth: 400

    readonly property int _leadX: 18       // 首点与 Y 轴之间的空隙
    property int selIdx: -1                // 气泡选中的数据点（-1 = 未选）

    // ⚠️ 别写成 ceil(v/5)*5 —— 那样 v=8 时会被抬到 10（多出一整个空档）。
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

    // ⚠️ 宽度 = max(可视区, 按天数算出来的宽度)：
    //    只有一个日期时按天数算只有一百多像素，虚线和坐标轴会缩成一小截。
    property real contentWidth: {
        var ds = _days()
        var span = ds.length ? ds[ds.length - 1].ord - ds[0].ord + 1 : 1
        return Math.max(viewWidth, 40 + _leadX + span * root.pxPerDay + 14)
    }

    onTransactionsChanged: { selIdx = -1; requestPaint() }
    onClassMaxDailyChanged: requestPaint()
    onClassMinDailyChanged: requestPaint()
    Component.onCompleted: requestPaint()

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

    // 折线上的点：首日**前一天**落在 0 线上的起笔点（anchor）+ 每个有记录的日子
    function _pts(g) {
        var ds = _days()
        if (!ds.length) return []
        var out = [{ ord: ds[0].ord - 1, val: 0, anchor: true }]
        for (var i = 0; i < ds.length; i++) out.push(ds[i])
        var x0 = g.x0
        for (i = 0; i < out.length; i++) {
            out[i].x = x0 + (out[i].ord - ds[0].ord + 1) * root.pxPerDay
            out[i].y = g.py(out[i].val)
        }
        return out
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            var g = root._geom()
            var pts = root._pts(g)
            var best = -1, bestD = 999
            for (var i = 0; i < pts.length; i++) {
                if (pts[i].anchor) continue
                var d = Math.sqrt((m.x - pts[i].x) * (m.x - pts[i].x) + (m.y - pts[i].y) * (m.y - pts[i].y))
                if (d < bestD) { bestD = d; best = i }
            }
            root.selIdx = bestD <= 18 ? (root.selIdx === best ? -1 : best) : -1
            root.requestPaint()
        }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var g = root._geom()
        var ch = g.ch
        var pts = root._pts(g)
        var right = width - 14                      // 虚线/坐标轴画到画布最右端

        // ── 其余刻度线：虚线，一律延伸到最右端 ──
        ctx.strokeStyle = "#dfe9e4"; ctx.lineWidth = 0.7
        ctx.setLineDash([3, 4])
        ctx.fillStyle = "#6b7d75"; ctx.font = "8px 'MiSans'"
        ctx.textAlign = "right"; ctx.textBaseline = "middle"
        for (var yv = Math.ceil(root.bottomVal / 2) * 2; yv <= root.topVal; yv += 2) {
            if (Math.abs(yv) < 0.001) continue
            var gy = g.py(yv)
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(right, gy); ctx.stroke()
            ctx.fillText(yv > 0 ? "+" + yv : String(yv), padL - 6, gy)
        }
        ctx.setLineDash([])

        // ── X 轴（0 线）：实线、加粗，同样到最右端 ──
        ctx.strokeStyle = "#9fd8c6"; ctx.lineWidth = 1.8
        ctx.beginPath(); ctx.moveTo(padL, g.py(0)); ctx.lineTo(right, g.py(0)); ctx.stroke()
        ctx.fillStyle = "#6b7d75"; ctx.textAlign = "right"; ctx.textBaseline = "middle"
        ctx.fillText("0", padL - 6, g.py(0))

        if (!pts.length) return

        // 面积填充（线到 X 轴之间）
        if (pts.length > 1) {
            var grad = ctx.createLinearGradient(0, padT, 0, padT + ch)
            grad.addColorStop(0, "rgba(14,140,119,0.20)")
            grad.addColorStop(1, "rgba(14,140,119,0.02)")
            ctx.beginPath()
            ctx.moveTo(pts[0].x, g.py(0))
            for (var i = 0; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
            ctx.lineTo(pts[pts.length - 1].x, g.py(0))
            ctx.closePath()
            ctx.fillStyle = grad; ctx.fill()
        }

        // 折线（从 0 点起笔）
        ctx.strokeStyle = "#0e8c77"; ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (i = 0; i < pts.length; i++) {
            if (i) ctx.lineTo(pts[i].x, pts[i].y)
            else ctx.moveTo(pts[i].x, pts[i].y)
        }
        ctx.stroke()

        // 数据点 + **每个点都标分数** + 日期（在 X 轴下方）
        ctx.textAlign = "center"
        var lastDateX = -999
        for (i = 0; i < pts.length; i++) {
            if (pts[i].anchor) continue                  // 起笔点不画点、不标分数
            var neg = pts[i].val < 0
            ctx.beginPath(); ctx.arc(pts[i].x, pts[i].y, i === root.selIdx ? 5 : 4, 0, Math.PI * 2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.strokeStyle = neg ? "#e3686b" : "#0e8c77"; ctx.lineWidth = 2; ctx.stroke()

            // 分数：**每个点都标**（用户明确要求）
            ctx.font = "bold 9px 'MiSans'"
            ctx.fillStyle = neg ? "#e3686b" : "#0e8c77"
            ctx.fillText(pts[i].val > 0 ? "+" + pts[i].val : String(pts[i].val), pts[i].x, pts[i].y - 10)

            // 日期：离上一个太近就跳过 —— 分数是信息、日期只是坐标，重叠时优先保分数
            if (pts[i].x - lastDateX >= 34) {
                ctx.font = "8px 'MiSans'"
                ctx.fillStyle = "#6b7d75"
                ctx.fillText(pts[i].date, pts[i].x, padT + ch + 13)
                lastDateX = pts[i].x
            }
        }

        // ── 气泡：**与折线同色**、带小尖尖指向该点 ──
        if (root.selIdx >= 0 && root.selIdx < pts.length && !pts[root.selIdx].anchor) {
            var p = pts[root.selIdx]
            var lines = []
            var agg = {}
            for (i = 0; i < p.items.length; i++) agg[p.items[i].cat] = (agg[p.items[i].cat] || 0) + p.items[i].val
            for (var k in agg) lines.push(k + (agg[k] > 0 ? " +" : " ") + agg[k] + " 分")
            if (!lines.length) lines.push("无记录")

            ctx.font = "9px 'MiSans'"
            var bw = 56, th = 13
            for (i = 0; i < lines.length; i++) bw = Math.max(bw, ctx.measureText(lines[i]).width + 20)
            var bh = lines.length * th + 12
            var tipH = 6                                    // 尖尖高度

            // 优先放在点上方；上方放不下就放下方
            var up = true
            var bx = p.x - bw / 2
            var by = p.y - bh - tipH - 6
            if (by < 2) { up = false; by = p.y + tipH + 12 }
            if (bx < 2) bx = 2
            if (bx + bw > width - 2) bx = width - 2 - bw

            var green = "#0e8c77"
            ctx.fillStyle = green

            // 气泡主体
            var rr = 7, r2 = bx + bw, b2 = by + bh
            ctx.beginPath()
            ctx.moveTo(bx + rr, by)
            ctx.lineTo(r2 - rr, by); ctx.quadraticCurveTo(r2, by, r2, by + rr)
            ctx.lineTo(r2, b2 - rr); ctx.quadraticCurveTo(r2, b2, r2 - rr, b2)
            ctx.lineTo(bx + rr, b2); ctx.quadraticCurveTo(bx, b2, bx, b2 - rr)
            ctx.lineTo(bx, by + rr); ctx.quadraticCurveTo(bx, by, bx + rr, by)
            ctx.closePath(); ctx.fill()

            // 小尖尖：从气泡边缘指向数据点
            var tipX = Math.max(bx + 10, Math.min(r2 - 10, p.x))
            ctx.beginPath()
            if (up) {                                       // 尖尖朝下
                ctx.moveTo(tipX - 5, b2 - 1)
                ctx.lineTo(tipX + 5, b2 - 1)
                ctx.lineTo(p.x, p.y - 4)
            } else {                                        // 尖尖朝上
                ctx.moveTo(tipX - 5, by + 1)
                ctx.lineTo(tipX + 5, by + 1)
                ctx.lineTo(p.x, p.y + 4)
            }
            ctx.closePath(); ctx.fill()

            // 文字
            ctx.fillStyle = "#ffffff"; ctx.font = "9px 'MiSans'"
            ctx.textAlign = "left"; ctx.textBaseline = "middle"
            for (i = 0; i < lines.length; i++)
                ctx.fillText(lines[i], bx + 10, by + 9 + i * th)
        }
    }
}
