import QtQuick

// 学习趋势折线图：**每天**的净分（加分 − 扣分），按真实日期比例排布。
//
// 刻度：默认 −5..+8（一天的量程），个别超常数据会扩到 5 的整数倍，绝不夹平。
//
// 读图结构：
// · X 轴 = 0 线（实线加粗）；其余平行刻度线 = 虚线，且一律画到画布最右端。
// · 每个分值点**垂直**用虚线连到 X 轴，**日期写在 X 轴下方、正对该点**。
// · 折线从 0 点起笔（首日的前一天），该起笔点不画点、不标分数。
// · 每个数据点上方都标分数。
// · 点数据点 → 弹气泡（与折线同色、带小尖尖），**淡入 + 轻微缩放**，不再生硬。
Item {
    id: root

    property var transactions: []
    property real classMaxDaily: 0
    property real classMinDaily: 0
    property real viewWidth: 400

    readonly property int _leadX: 18
    property int selIdx: -1

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
        var span = ds.length ? ds[ds.length - 1].ord - ds[0].ord + 1 : 1
        return Math.max(viewWidth, 40 + _leadX + span * root.pxPerDay + 14)
    }

    readonly property int padL: 40
    readonly property int padT: 26
    readonly property int padB: 28

    function _geom() {
        var ch = height - padT - padB
        var yRange = topVal - bottomVal
        return { ch: ch, yRange: yRange, x0: padL + _leadX,
                 py: function(v) {
                     var c = Math.max(bottomVal, Math.min(topVal, v))
                     return padT + ch - ((c - bottomVal) / yRange) * ch
                 } }
    }

    function _pts(g) {
        var ds = _days()
        if (!ds.length) return []
        var out = [{ ord: ds[0].ord - 1, val: 0, anchor: true }]
        for (var i = 0; i < ds.length; i++) out.push(ds[i])
        for (i = 0; i < out.length; i++) {
            out[i].x = g.x0 + (out[i].ord - ds[0].ord + 1) * root.pxPerDay
            out[i].y = g.py(out[i].val)
        }
        return out
    }

    // 气泡里要显示的明细（同维度合并）
    readonly property var _bubbleLines: {
        if (selIdx < 0) return []
        var pts = _pts(_geom())
        if (selIdx >= pts.length || pts[selIdx].anchor) return []
        var p = pts[selIdx], agg = {}
        for (var i = 0; i < p.items.length; i++)
            agg[p.items[i].cat] = (agg[p.items[i].cat] || 0) + p.items[i].val
        var out = []
        for (var k in agg) out.push(k + (agg[k] > 0 ? " +" : " ") + agg[k] + " 分")
        return out.length ? out : ["无记录"]
    }
    readonly property var _selPt: {
        if (selIdx < 0) return null
        var pts = _pts(_geom())
        return (selIdx < pts.length && !pts[selIdx].anchor) ? pts[selIdx] : null
    }

    onTransactionsChanged: { selIdx = -1; cv.requestPaint() }
    onClassMaxDailyChanged: cv.requestPaint()
    onClassMinDailyChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    Component.onCompleted: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var g = root._geom()
            var ch = g.ch
            var pts = root._pts(g)
            var right = width - 14
            var y0 = g.py(0)

            // 其余刻度线：虚线，延伸到最右端
            ctx.strokeStyle = "#dfe9e4"; ctx.lineWidth = 0.7
            ctx.setLineDash([3, 4])
            ctx.fillStyle = "#6b7d75"; ctx.font = "8px 'MiSans'"
            ctx.textAlign = "right"; ctx.textBaseline = "middle"
            for (var yv = Math.ceil(root.bottomVal / 2) * 2; yv <= root.topVal; yv += 2) {
                if (Math.abs(yv) < 0.001) continue
                var gy = g.py(yv)
                ctx.beginPath(); ctx.moveTo(root.padL, gy); ctx.lineTo(right, gy); ctx.stroke()
                ctx.fillText(yv > 0 ? "+" + yv : String(yv), root.padL - 6, gy)
            }
            ctx.setLineDash([])

            // X 轴（0 线）：实线加粗
            ctx.strokeStyle = "#9fd8c6"; ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(root.padL, y0); ctx.lineTo(right, y0); ctx.stroke()
            ctx.fillStyle = "#6b7d75"; ctx.textAlign = "right"; ctx.textBaseline = "middle"
            ctx.fillText("0", root.padL - 6, y0)

            if (!pts.length) return

            // 每个点 → X 轴的垂直虚线（读图用）
            ctx.strokeStyle = "#c9e4da"; ctx.lineWidth = 0.9
            ctx.setLineDash([2, 3])
            for (var i = 0; i < pts.length; i++) {
                if (pts[i].anchor) continue
                ctx.beginPath(); ctx.moveTo(pts[i].x, pts[i].y); ctx.lineTo(pts[i].x, y0); ctx.stroke()
            }
            ctx.setLineDash([])

            // 面积填充
            if (pts.length > 1) {
                var grad = ctx.createLinearGradient(0, root.padT, 0, root.padT + ch)
                grad.addColorStop(0, "rgba(14,140,119,0.20)")
                grad.addColorStop(1, "rgba(14,140,119,0.02)")
                ctx.beginPath(); ctx.moveTo(pts[0].x, y0)
                for (i = 0; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
                ctx.lineTo(pts[pts.length - 1].x, y0)
                ctx.closePath(); ctx.fillStyle = grad; ctx.fill()
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

            // 数据点 + 每个点标分数 + **日期写在 X 轴正下方**
            ctx.textAlign = "center"
            var lastDateX = -999
            for (i = 0; i < pts.length; i++) {
                if (pts[i].anchor) continue
                var neg = pts[i].val < 0
                ctx.beginPath(); ctx.arc(pts[i].x, pts[i].y, i === root.selIdx ? 5 : 4, 0, Math.PI * 2)
                ctx.fillStyle = "#ffffff"; ctx.fill()
                ctx.strokeStyle = neg ? "#e3686b" : "#0e8c77"; ctx.lineWidth = 2; ctx.stroke()

                ctx.font = "bold 9px 'MiSans'"
                ctx.fillStyle = neg ? "#e3686b" : "#0e8c77"
                ctx.fillText(pts[i].val > 0 ? "+" + pts[i].val : String(pts[i].val), pts[i].x, pts[i].y - 10)

                if (pts[i].x - lastDateX >= 34) {
                    ctx.font = "8px 'MiSans'"
                    ctx.fillStyle = "#6b7d75"
                    ctx.fillText(pts[i].date, pts[i].x, y0 + 13)     // ← 贴近 X 轴下方
                    lastDateX = pts[i].x
                }
            }
        }
    }

    // ── 气泡：QML 元素（可动画），与折线同色，带小尖尖 ──
    Item {
        id: bubble
        readonly property var pt: root._selPt
        readonly property bool up: pt ? (pt.y - height - 16 >= 2) : true

        // 入场：淡化 + 轻微缩放（不再生硬地"啪"一下出现）
        opacity: pt ? 1 : 0
        scale: pt ? 1 : 0.9
        transformOrigin: up ? Item.Bottom : Item.Top
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        width: body.width
        height: body.height + 6
        x: pt ? Math.max(2, Math.min(root.width - width - 2, pt.x - width / 2)) : 0
        y: pt ? (up ? pt.y - height - 8 : pt.y + 8) : 0

        Rectangle {                                  // 小尖尖（旋转 45° 的小方块，半截探出）
            width: 10; height: 10
            color: "#0e8c77"
            rotation: 45
            x: body.width / 2 - 5
            y: bubble.up ? body.height - 5 : 1
        }
        Rectangle {
            id: body
            width: col.implicitWidth + 20
            height: col.implicitHeight + 12
            radius: 7
            color: "#0e8c77"
            Column {
                id: col
                anchors.centerIn: parent
                spacing: 1
                Repeater {
                    model: root._bubbleLines
                    delegate: Text {
                        text: modelData
                        color: "#ffffff"
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
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
            cv.requestPaint()
        }
    }
}
