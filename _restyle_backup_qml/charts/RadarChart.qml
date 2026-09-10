import QtQuick

// 六维雷达图（Canvas 绘制）
// 同心六边形刻度：总分 30，每 5 分一层；值封顶到最大刻度。
Canvas {
    id: root

    property var scores: []           // 6 个维度的数值
    property var categories: []       // 6 个维度名
    property real maxVal: 30          // 总分刻度
    property real step: 5             // 每格分差

    onScoresChanged: requestPaint()
    onCategoriesChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (!root.scores.length || !root.categories.length) return

        var w = width, h = height, cx = w / 2, cy = h / 2
        var r = Math.min(w, h) * 0.30
        var n = root.categories.length
        var stepA = Math.PI * 2 / n, start = -Math.PI / 2
        var i, a, x, y, rr, v
        var layers = Math.round(root.maxVal / root.step)

        // 同心六边形刻度：由内向外逐层 5/10/15/20/25/30，内层更浅
        for (var layer = 1; layer <= layers; layer++) {
            rr = r * layer / layers
            ctx.beginPath()
            for (i = 0; i < n; i++) {
                a = start + i * stepA
                x = cx + rr * Math.cos(a); y = cy + rr * Math.sin(a)
                if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y)
            }
            ctx.closePath()
            ctx.strokeStyle = layer === layers ? "#b9cbdd" : (layer % 2 === 0 ? "#dde5ee" : "#e8edf3")
            ctx.lineWidth = layer === layers ? 1.5 : 0.8
            ctx.stroke()

            // 每层刻度值（标在顶部轴线旁，错开避免重叠）
            var tickVal = layer * root.step
            var tx = cx + rr * Math.cos(start)
            var ty = cy + rr * Math.sin(start)
            ctx.fillStyle = "#98a1b0"
            ctx.font = "8px 'MiSans'"
            ctx.textAlign = "left"; ctx.textBaseline = "middle"
            ctx.fillText(String(tickVal), tx + 3, ty)
        }

        // 轴线
        for (i = 0; i < n; i++) {
            a = start + i * stepA
            ctx.beginPath(); ctx.moveTo(cx, cy)
            ctx.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a))
            ctx.strokeStyle = "#e3e8ee"; ctx.lineWidth = 0.6; ctx.stroke()
        }

        // 分数多边形（封顶到最大刻度，不越界）
        ctx.beginPath()
        for (i = 0; i < n; i++) {
            v = Math.min(Math.abs(root.scores[i]) / root.maxVal, 1)
            a = start + i * stepA
            x = cx + v * r * Math.cos(a); y = cy + v * r * Math.sin(a)
            if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y)
        }
        ctx.closePath()
        ctx.fillStyle = "rgba(77,130,189,0.16)"
        ctx.fill()
        ctx.strokeStyle = "#4d82bd"; ctx.lineWidth = 2; ctx.stroke()

        // 维度标签 + 分数
        ctx.textAlign = "center"; ctx.textBaseline = "middle"
        for (i = 0; i < n; i++) {
            a = start + i * stepA
            x = cx + (r + 22) * Math.cos(a); y = cy + (r + 22) * Math.sin(a)
            ctx.fillStyle = "#4d82bd"
            ctx.font = "10px 'MiSans'"
            ctx.fillText(root.categories[i], x, y - 7)
            ctx.fillStyle = "#6a7078"
            ctx.font = "9px 'MiSans'"
            ctx.fillText(root.scores[i] > 0 ? "+" + root.scores[i] : root.scores[i], x, y + 7)
        }
    }
}
