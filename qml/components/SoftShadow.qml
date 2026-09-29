import QtQuick

// 柔和光晕投影：径向渐变、边缘真正模糊（替代硬边矩形阴影）
Canvas {
    id: root
    property color softColor: Qt.rgba(0.25, 0.28, 0.42, 0.25)
    property real centerY: 0.58          // 光心略下移 → 读作投影而非发光
    // 只画在某个 item 的轮廓内：非空时把超出该轮廓的部分裁掉
    // （默认 null = 不裁剪，主面板/Dock/水印等既有用法完全不受影响）
    property Item clipTo: null
    property real clipRad: 0
    onSoftColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onClipToChanged: requestPaint()
    onClipRadChanged: requestPaint()

    function rgbaStr(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
                + Math.round(c.b * 255) + "," + a + ")"
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var w = width, h = height
        if (w < 4 || h < 4) return
        // 裁剪（在未变换的坐标系里做）：把 clipTo 的轮廓映射到本画布坐标后 clip
        if (root.clipTo) {
            var p = root.clipTo.mapToItem(root, 0, 0)
            var cw = root.clipTo.width, ch = root.clipTo.height
            var r = Math.max(0, Math.min(root.clipRad, Math.min(cw, ch) / 2))
            ctx.beginPath()
            ctx.moveTo(p.x + r, p.y)
            ctx.lineTo(p.x + cw - r, p.y); ctx.quadraticCurveTo(p.x + cw, p.y, p.x + cw, p.y + r)
            ctx.lineTo(p.x + cw, p.y + ch - r); ctx.quadraticCurveTo(p.x + cw, p.y + ch, p.x + cw - r, p.y + ch)
            ctx.lineTo(p.x + r, p.y + ch); ctx.quadraticCurveTo(p.x, p.y + ch, p.x, p.y + ch - r)
            ctx.lineTo(p.x, p.y + r); ctx.quadraticCurveTo(p.x, p.y, p.x + r, p.y)
            ctx.closePath()
            ctx.clip()
        }
        ctx.save()
        ctx.translate(w / 2, h * root.centerY)
        ctx.scale(1, h / w)                       // 圆压成椭圆适配胶囊
        var g = ctx.createRadialGradient(0, 0, 0, 0, 0, w / 2)
        g.addColorStop(0, rgbaStr(root.softColor, root.softColor.a))
        g.addColorStop(0.5, rgbaStr(root.softColor, root.softColor.a * 0.5))
        g.addColorStop(0.82, rgbaStr(root.softColor, root.softColor.a * 0.16))
        g.addColorStop(1, rgbaStr(root.softColor, 0))
        ctx.fillStyle = g
        // 已在 scale(1, h/w) 的上下文里：要覆盖整个画布(设备高 h)，缩放后高度须为 w
        // （否则 fillRect 高度 h 在设备空间变成 h*h/w，把椭圆上下裁出硬边 → 面板中部横线）
        ctx.fillRect(-w / 2, -root.centerY * w, w, w)
        ctx.restore()
    }
}
