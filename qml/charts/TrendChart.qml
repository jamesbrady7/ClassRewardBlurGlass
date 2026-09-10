import QtQuick

// 学习趋势折线图（Canvas 绘制）：加分/扣分按日期累计。
// 按自然日（00:00）聚合，再按时间先后排序绘制，避免 8/9 月跨月错乱。
Canvas {
    id: root

    property var transactions: []
    property real topVal: 10
    property real bottomVal: -5
    property real dateStep: 56        // 固定横向间距，日期多时可滚动

    function _days() {
        var map = {}
        var arr = root.transactions
        for (var i = 0; i < arr.length; i++) {
            var t = arr[i]
            if (t.type !== "earn" && t.type !== "deduct") continue
            var d = new Date(t.ts * 1000)
            var key = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
            map[key] = (map[key] || 0) + (t.type === "earn" ? t.points : -t.points)
        }
        var keys = Object.keys(map).map(Number).sort(function(x, y) { return x - y })
        var out = []
        for (var k = 0; k < keys.length; k++) {
            var kk = keys[k]
            out.push({ key: kk, date: Math.floor(kk / 100) % 100 + "/" + kk % 100, val: map[kk] })
        }
        return out
    }

    property real contentWidth: 40 + Math.max(1, _days().length - 1) * root.dateStep + 24

    onTransactionsChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var days = root._days()
        if (!days.length) return

        // 累计折线（严格按时间顺序累计）
        var pts = [], cum = 0
        for (var i = 0; i < days.length; i++) {
            cum += days[i].val
            pts.push({ val: cum, date: days[i].date })
        }

        var w = width, h = height
        var padL = 40, padR = 14, padT = 26, padB = 28
        var ch = h - padT - padB
        var stepX = root.dateStep
        var cw = (pts.length - 1) * stepX
        var yRange = root.topVal - root.bottomVal

        function px(i) { return padL + i * stepX }
        function py(v) {
            var c = Math.max(root.bottomVal, Math.min(root.topVal, v))
            return padT + ch - ((c - root.bottomVal) / yRange) * ch
        }

        // Y 轴网格（每 5 一格）
        ctx.strokeStyle = "#e8eee9"; ctx.lineWidth = 0.5
        ctx.fillStyle = "#6b7d75"; ctx.font = "8px 'MiSans'"
        ctx.textAlign = "right"; ctx.textBaseline = "middle"
        for (var yv = Math.ceil(root.bottomVal / 5) * 5; yv <= root.topVal; yv += 5) {
            var gy = py(yv)
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(padL + cw, gy); ctx.stroke()
            ctx.fillText(yv > 0 ? "+" + yv : yv, padL - 6, gy)
        }

        // 零线（虚线）
        ctx.strokeStyle = "#b9e2d4"; ctx.lineWidth = 1.4
        ctx.setLineDash([4, 3])
        ctx.beginPath(); ctx.moveTo(padL, py(0)); ctx.lineTo(padL + cw, py(0)); ctx.stroke()
        ctx.setLineDash([])

        // 面积填充
        if (pts.length > 1) {
            var grad = ctx.createLinearGradient(0, padT, 0, padT + ch)
            grad.addColorStop(0, "rgba(14,140,119,0.20)")
            grad.addColorStop(1, "rgba(14,140,119,0.02)")
            ctx.beginPath()
            ctx.moveTo(px(0), py(0))
            for (i = 0; i < pts.length; i++) ctx.lineTo(px(i), py(pts[i].val))
            ctx.lineTo(px(pts.length - 1), py(0))
            ctx.closePath()
            ctx.fillStyle = grad; ctx.fill()
        }

        // 折线
        ctx.strokeStyle = "#0e8c77"; ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (i = 0; i < pts.length; i++) { if (i) ctx.lineTo(px(i), py(pts[i].val)); else ctx.moveTo(px(i), py(pts[i].val)) }
        ctx.stroke()

        // 数据点 + 值 + 日期
        ctx.textAlign = "center"
        for (i = 0; i < pts.length; i++) {
            var x = px(i), y = py(pts[i].val)
            ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.strokeStyle = pts[i].val >= 0 ? "#0e8c77" : "#e3686b"; ctx.lineWidth = 2; ctx.stroke()

            ctx.font = "bold 9px 'MiSans'"
            ctx.fillStyle = pts[i].val >= 0 ? "#0e8c77" : "#e3686b"
            ctx.fillText(pts[i].val > 0 ? "+" + pts[i].val : pts[i].val, x, y - 10)
            ctx.font = "8px 'MiSans'"
            ctx.fillStyle = "#6b7d75"
            ctx.fillText(pts[i].date, x, padT + ch + 13)
        }
    }
}
