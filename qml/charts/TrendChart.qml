import QtQuick

// 学习趋势折线图（Canvas 绘制）：**每天**的净分（加分 − 扣分），按真实日期比例排布。
//
// ── 刻度：固定 −5..+8（一天的量程），永远不随学期变大 ──────────
// 用户给定的事实：一天之内加分不超过 8、扣分不超过 5。
// 所以这是"每天"的图，Y 轴天然就是 −5..+8 —— 一学期用下来也不需要改刻度。
// （原来画的是**累计**，Y 轴却写死 −5..+10：真实班里一个学生 3 天累计到 +39，
//   折线当场贴在顶边变横线。改成按天之后，量程就由"单日上限"决定了。）
// 万一个别数据超了（如批量补录），轴会向上/向下扩一整档，**绝不夹平**。
//
// 另两处修正：
// ② X 轴按**真实日期差**比例（原来按"有记录的天数"等距排，
//    8/16→8/20 的 4 天和 8/15→8/16 的 1 天一样宽 → 斜率没有时间含义）。
// ③ 每天像素宽按视口自适应：放得下就撑满、放不下才滚动。
Canvas {
    id: root

    property var transactions: []
    property real classMaxDaily: 0    // 全班单日最高（调用方传入；正常 ≤ 8）
    property real classMinDaily: 0    // 全班单日最低（可负；正常 ≥ -5）
    property real viewWidth: 400      // 可视区宽度

    // 单日量程：默认 −5..+8，超出才扩档（5 的整数倍）
    readonly property real topVal: Math.max(8, Math.ceil(classMaxDaily / 5) * 5)
    readonly property real bottomVal: Math.min(-5, Math.floor(classMinDaily / 5) * 5)

    // 每天像素宽：放得下就撑满可视区，放不下才滚动（下限 14：再窄日期标签会叠）
    property real pxPerDay: Math.max(14, Math.min(48, (viewWidth - 54) / Math.max(1, _spanDays())))
    function _spanDays() {
        var ds = _days()
        if (ds.length < 2) return 1
        return ds[ds.length - 1].ord - ds[0].ord + 1
    }

    // 按自然日聚合（**不累计**）；日序号用 UTC 天数算，跨月/跨年都不会错
    function _days() {
        var map = {}
        var arr = root.transactions
        for (var i = 0; i < arr.length; i++) {
            var t = arr[i]
            if (t.type !== "earn" && t.type !== "deduct") continue
            var d = new Date(t.ts * 1000)
            var ord = Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000)
            var e = map[ord]
            if (!e) { e = { ord: ord, val: 0, date: (d.getMonth() + 1) + "/" + d.getDate() }; map[ord] = e }
            e.val += (t.type === "earn" ? t.points : -t.points)
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
        return 40 + span * root.pxPerDay + 14
    }

    onTransactionsChanged: requestPaint()
    onClassMaxDailyChanged: requestPaint()
    onClassMinDailyChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var pts = root._days()
        if (!pts.length) return

        var w = width, h = height
        var padL = 40, padR = 14, padT = 26, padB = 28
        var ch = h - padT - padB
        var ord0 = pts[0].ord
        var cw = (pts[pts.length - 1].ord - ord0) * root.pxPerDay
        var yRange = root.topVal - root.bottomVal

        // X 按真实日期差比例
        function px(p) { return padL + (p.ord - ord0) * root.pxPerDay }
        function py(v) {
            var c = Math.max(root.bottomVal, Math.min(root.topVal, v))
            return padT + ch - ((c - root.bottomVal) / yRange) * ch
        }

        // Y 轴网格（固定 2 一格：−5..+8 的量程下共 7 条，正好）
        var gridStep = 2
        ctx.strokeStyle = "#e8eee9"; ctx.lineWidth = 0.5
        ctx.fillStyle = "#6b7d75"; ctx.font = "8px 'MiSans'"
        ctx.textAlign = "right"; ctx.textBaseline = "middle"
        for (var yv = Math.ceil(root.bottomVal / gridStep) * gridStep; yv <= root.topVal; yv += gridStep) {
            var gy = py(yv)
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(padL + cw, gy); ctx.stroke()
            ctx.fillText(yv > 0 ? "+" + yv : String(yv), padL - 6, gy)
        }

        // 零线（虚线）
        ctx.strokeStyle = "#b9e2d4"; ctx.lineWidth = 1.4
        ctx.setLineDash([4, 3])
        ctx.beginPath(); ctx.moveTo(padL, py(0)); ctx.lineTo(padL + cw, py(0)); ctx.stroke()
        ctx.setLineDash([])

        // 面积填充（线到零线之间）
        if (pts.length > 1) {
            var grad = ctx.createLinearGradient(0, padT, 0, padT + ch)
            grad.addColorStop(0, "rgba(14,140,119,0.20)")
            grad.addColorStop(1, "rgba(14,140,119,0.02)")
            ctx.beginPath()
            ctx.moveTo(px(pts[0]), py(0))
            for (var i = 0; i < pts.length; i++) ctx.lineTo(px(pts[i]), py(pts[i].val))
            ctx.lineTo(px(pts[pts.length - 1]), py(0))
            ctx.closePath()
            ctx.fillStyle = grad; ctx.fill()
        }

        // 折线
        ctx.strokeStyle = "#0e8c77"; ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (i = 0; i < pts.length; i++) {
            if (i) ctx.lineTo(px(pts[i]), py(pts[i].val))
            else ctx.moveTo(px(pts[i]), py(pts[i].val))
        }
        ctx.stroke()

        // 数据点 + 值 + 日期
        ctx.textAlign = "center"
        for (i = 0; i < pts.length; i++) {
            var x = px(pts[i]), y = py(pts[i].val)
            ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.strokeStyle = pts[i].val >= 0 ? "#0e8c77" : "#e3686b"; ctx.lineWidth = 2; ctx.stroke()

            ctx.font = "bold 9px 'MiSans'"
            ctx.fillStyle = pts[i].val >= 0 ? "#0e8c77" : "#e3686b"
            ctx.fillText(pts[i].val > 0 ? "+" + pts[i].val : String(pts[i].val), x, y - 10)
            ctx.font = "8px 'MiSans'"
            ctx.fillStyle = "#6b7d75"
            ctx.fillText(pts[i].date, x, padT + ch + 13)
        }
    }
}
