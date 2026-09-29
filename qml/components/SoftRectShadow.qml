import QtQuick

// 圆角矩形柔和投影：形状与卡片一致（同一 rad），边缘由多层外扩做**渐变式羽化**。
// 用途：卡片悬停上浮时投在背板上的影（形状=卡片、整体下移、横向略窄）。
//
// 为什么不用 SoftShadow：那是**径向椭圆**，形状和卡片对不上（用户要"影子就是卡片的形状"）。
// 本 Qt 的 Canvas 不支持高斯模糊/shadowBlur，所以用"由外向内逐层填充圆角矩形、
// 每层等量 alpha 叠加"凑出平滑衰减——层数够多时肉眼就是连续的羽化。
//
// 画布尺寸 = 影子矩形 + 四周 feather；影子矩形在画布内的位置 =(feather, feather)。
Canvas {
    id: root
    property color softColor: Qt.rgba(0, 0, 0, 0)
    property real rad: 18
    property real feather: 18        // 羽化宽度（向外扩散多远）
    property real shadowW: 100       // 影子矩形尺寸
    property real shadowH: 100
    property int layers: 18

    implicitWidth: shadowW + 2 * feather
    implicitHeight: shadowH + 2 * feather

    onSoftColorChanged: requestPaint()
    onRadChanged: requestPaint()
    onFeatherChanged: requestPaint()
    onShadowWChanged: requestPaint()
    onShadowHChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function rgbaStr(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
                + Math.round(c.b * 255) + "," + a.toFixed(4) + ")"
    }

    function roundRectPath(ctx, x, y, w, h, r) {
        r = Math.max(0, Math.min(r, Math.min(w, h) / 2))
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r)
        ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
        ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r)
        ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y)
        ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var f = root.feather
        var bw = root.shadowW, bh = root.shadowH
        if (bw < 1 || bh < 1 || f <= 0) return
        var per = root.softColor.a / root.layers
        if (per <= 0.0003) return
        // 从最外圈（最大、最淡）到影子本体（最小、最浓）逐层叠加 → 向外平滑衰减
        for (var i = root.layers - 1; i >= 0; i--) {
            var t = i / (root.layers - 1)          // 1=最外圈
            var g = f * t
            ctx.fillStyle = rgbaStr(root.softColor, per)
            roundRectPath(ctx, f - g, f - g, bw + 2 * g, bh + 2 * g, root.rad + g)
            ctx.fill()
        }
    }
}
