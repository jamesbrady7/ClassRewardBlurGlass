import QtQuick

// 六维雷达图（Canvas 绘制）
//
// ── 刻度：全班组共用、按 "学期容量" 分档向上 ──────────────────
// 需求前提：**一学期长期使用**，所以刻度既不能按单个学生自适应（学生之间没法比），
// 也不能写死一个学期满额的大数（开学前几周所有图都缩成中心一个点）。
// 做法：按**全班**单维最高分，落到固定档位里取"刚好装得下"的一档：
//     20 / 30 / 50 / 100 / 150 / 200 / 300 / 500
//   · 同一时刻所有学生共用同一档 → 形状可比
//   · 数据长上去只会往上一档跳，**永远不封顶**
//   · 开学时档位低，形状仍然看得清
//
// ── 负值 ─────────────────────────────────────────────────
// scores 是**净分**（加分−扣分），可以是负数。旧代码用了 Math.abs()，
// 于是 -4 和 +4 画出来一模一样 —— 一张"纪律被扣 4 分"的图看着像"加了 4 分"。
// 现在：半径只取正部分（负值 → 圆心），但**该维度的数值标红**，扣分一眼可见。
Canvas {
    id: root

    property var scores: []           // 6 个维度的净分（可负）
    property var categories: []       // 6 个维度名
    property real classMax: 0         // 全班单维最高分（调用方传入，用于定档）

    // 档位表：刻度值 → 每格步长（格子数 = 值/步长，控制在 4~6 格）
    readonly property var _ladder: [
        { v: 20,  step: 5   }, { v: 30,  step: 5   }, { v: 50,  step: 10  },
        { v: 100, step: 20  }, { v: 150, step: 25  }, { v: 200, step: 50  },
        { v: 300, step: 50  }, { v: 500, step: 100 }
    ]
    readonly property var _scale: {
        for (var i = 0; i < _ladder.length; i++)
            if (classMax <= _ladder[i].v) return _ladder[i]
        return _ladder[_ladder.length - 1]      // 超出最大档 → 用最大档（几乎不可能）
    }
    readonly property real maxVal: _scale.v
    readonly property real step: _scale.step

    onScoresChanged: requestPaint()
    onCategoriesChanged: requestPaint()
    onClassMaxChanged: requestPaint()
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

        // 同心六边形刻度：由内向外逐层，内层更浅
        for (var layer = 1; layer <= layers; layer++) {
            rr = r * layer / layers
            ctx.beginPath()
            for (i = 0; i < n; i++) {
                a = start + i * stepA
                x = cx + rr * Math.cos(a); y = cy + rr * Math.sin(a)
                if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y)
            }
            ctx.closePath()
            ctx.strokeStyle = layer === layers ? "#bfe8de" : (layer % 2 === 0 ? "#dcebe4" : "#e9f0ec")
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
            ctx.strokeStyle = "#e8eee9"; ctx.lineWidth = 0.6; ctx.stroke()
        }

        // 分数多边形：半径只取**正部分**（负值落在圆心）
        ctx.beginPath()
        for (i = 0; i < n; i++) {
            v = Math.max(0, Math.min(root.scores[i], root.maxVal)) / root.maxVal
            a = start + i * stepA
            x = cx + v * r * Math.cos(a); y = cy + v * r * Math.sin(a)
            if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y)
        }
        ctx.closePath()
        ctx.fillStyle = "rgba(15,168,143,0.18)"
        ctx.fill()
        ctx.strokeStyle = "#0e8c77"; ctx.lineWidth = 2; ctx.stroke()

        // 维度标签 + 分数（负分标红 —— 扣分维度在雷达上半径归零，靠这里区分）
        ctx.textAlign = "center"; ctx.textBaseline = "middle"
        for (i = 0; i < n; i++) {
            a = start + i * stepA
            x = cx + (r + 22) * Math.cos(a); y = cy + (r + 22) * Math.sin(a)
            var neg = root.scores[i] < 0
            ctx.fillStyle = neg ? "#d2554f" : "#0e8c77"
            ctx.font = "10px 'MiSans'"
            ctx.fillText(root.categories[i], x, y - 7)
            ctx.fillStyle = neg ? "#d2554f" : "#5b6472"
            ctx.font = "9px 'MiSans'"
            ctx.fillText(root.scores[i] > 0 ? "+" + root.scores[i] : root.scores[i], x, y + 7)
        }
    }
}
