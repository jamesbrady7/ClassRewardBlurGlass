import QtQuick

// 学习趋势折线图（Canvas 绘制）：加分/扣分按日期累计。
//
// ── 三处关键修正（都是"图在说假话"级别）────────────────────
// ① Y 轴原先写死 -5..+10，超出会被**静默夹平**：
//      实测真实班里一个学生 3 天就累计到 +39 → 折线直接贴在顶边成一条横线。
//    现在按**全班**累计的极值分档（10/20/50/100/150/200/300/500/1000），
//    且负半轴**只在真的有扣分时**才留（原来恒定 -5..0 全是浪费）。
// ② X 轴原先按"有记录的天数"等距排（`padL + i*stepX`），
//    于是 8/16→8/20（4 天）和 8/15→8/16（1 天）一样宽 → 斜率没有时间含义。
//    现在按**真实日期差**比例布置。
// ③ 折线没有 0 起点：第一个点直接落在第一天累计值上，像凭空悬在半空。
//    现在在首笔交易**前一天**补一个 0 点，折线从基线出发。
Canvas {
    id: root

    property var transactions: []
    property real classMaxCum: 0      // 全班最高累计（调用方传入，用于定档）
    property real classMinCum: 0      // 全班最低累计（可负）
    property real viewWidth: 400      // 可视区宽度（由调用方传入，用来算"放得下就撑满"）
    // 每天的像素宽：**放得下就撑满可视区，放不下才滚动**。
    // 原来是写死的 56（按"有记录的天数"排），改成按真实日期后，
    // 固定 px/天会让短周期的图撑不满、长周期又滚得太长。
    // 14 是下限：一天一格再窄，日期标签（"8/15" 约 20px）就会叠在一起。
    property real pxPerDay: Math.max(14, Math.min(48, (viewWidth - 54) / Math.max(1, _spanDays())))
    function _spanDays() {
        var ds = _days()
        if (ds.length < 2) return 1
        return ds[ds.length - 1].ord - ds[0].ord + 1
    }

    // ── Y 刻度分档 ──
    readonly property var _upLadder:   [10, 20, 50, 100, 150, 200, 300, 500, 1000]
    readonly property var _downLadder: [5, 10, 20, 50, 100, 200, 500]
    function _pickUp(v) {
        for (var i = 0; i < _upLadder.length; i++) if (v <= _upLadder[i]) return _upLadder[i]
        return _upLadder[_upLadder.length - 1]
    }
    function _pickDown(v) {
        for (var i = 0; i < _downLadder.length; i++) if (v <= _downLadder[i]) return _downLadder[i]
        return _downLadder[_downLadder.length - 1]
    }
    readonly property real topVal: _pickUp(Math.max(0, classMaxCum))
    // 没有扣分就不留负半轴（原来恒定 -5..0，白白占掉一半画布）
    readonly property real bottomVal: classMinCum < 0 ? -_pickDown(-classMinCum) : 0

    // 按自然日聚合；同时给出**日序号**（用 UTC 天数算，跨月/跨年都不会错）
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
    onClassMaxCumChanged: requestPaint()
    onClassMinCumChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var days = root._days()
        if (!days.length) return

        // 累计折线（严格按时间顺序累计）
        var pts = [], cum = 0
        // ③ 首笔前一天补一个 0 点：折线从基线出发，而不是凭空悬在半空
        pts.push({ ord: days[0].ord - 1, val: 0, date: "", anchor: true })
        for (var i = 0; i < days.length; i++) {
            cum += days[i].val
            pts.push({ ord: days[i].ord, val: cum, date: days[i].date })
        }

        var w = width, h = height
        var padL = 40, padR = 14, padT = 26, padB = 28
        var ch = h - padT - padB
        var ord0 = pts[0].ord
        var cw = (pts[pts.length - 1].ord - ord0) * root.pxPerDay
        var yRange = root.topVal - root.bottomVal

        // ② X 按真实日期差比例
        function px(p) { return padL + (p.ord - ord0) * root.pxPerDay }
        function py(v) {
            var c = Math.max(root.bottomVal, Math.min(root.topVal, v))
            return padT + ch - ((c - root.bottomVal) / yRange) * ch
        }

        // Y 轴网格：步长随量程走（原来固定每 5 一格，量程一大就画成百上千条线）
        var gridStep = yRange / 6
        var mag = Math.pow(10, Math.floor(Math.log(gridStep) / Math.LN10))
        var norm = gridStep / mag
        gridStep = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10) * mag
        ctx.strokeStyle = "#e8eee9"; ctx.lineWidth = 0.5
        ctx.fillStyle = "#6b7d75"; ctx.font = "8px 'MiSans'"
        ctx.textAlign = "right"; ctx.textBaseline = "middle"
        for (var yv = Math.ceil(root.bottomVal / gridStep) * gridStep; yv <= root.topVal; yv += gridStep) {
            var gy = py(yv)
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(padL + cw, gy); ctx.stroke()
            ctx.fillText(yv > 0 ? "+" + Math.round(yv) : String(Math.round(yv)), padL - 6, gy)
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
            ctx.moveTo(px(pts[0]), py(0))
            for (i = 0; i < pts.length; i++) ctx.lineTo(px(pts[i]), py(pts[i].val))
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

        // 数据点 + 值 + 日期（补的 0 起点不画点、不标日期）
        ctx.textAlign = "center"
        for (i = 0; i < pts.length; i++) {
            if (pts[i].anchor) continue
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
