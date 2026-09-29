import QtQuick

// 24 网格线性图标（Canvas 手绘，避免字体/emoji 依赖）
Canvas {
    id: root
    property string name: ""
    property color color: "#3c4254"
    property real strokeW: 1.7
    width: 20; height: 20
    antialiasing: true

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function rrect(ctx, x, y, w, h, r) {
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
        if (width < 4) return
        var s = width / 24
        ctx.scale(s, s)
        var c = String(Qt.rgba(root.color.r, root.color.g, root.color.b, root.color.a))
        ctx.strokeStyle = c
        ctx.fillStyle = c
        ctx.lineWidth = root.strokeW
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        draw(ctx, root.name)
    }

    function draw(ctx, n) {
        var i, a, x, y, r
        ctx.beginPath()
        switch (n) {
        case "home":
            ctx.moveTo(4.5, 11); ctx.lineTo(12, 4.6); ctx.lineTo(19.5, 11)
            ctx.moveTo(6.4, 9.6); ctx.lineTo(6.4, 19.2); ctx.lineTo(17.6, 19.2); ctx.lineTo(17.6, 9.6)
            ctx.moveTo(10.2, 19.2); ctx.lineTo(10.2, 14.2); ctx.lineTo(13.8, 14.2); ctx.lineTo(13.8, 19.2)
            ctx.stroke(); break
        case "star":
            for (i = 0; i < 10; i++) {
                r = (i % 2 === 0) ? 8.8 : 4.1
                a = -Math.PI / 2 + i * Math.PI / 5
                x = 12 + r * Math.cos(a); y = 12.6 + r * Math.sin(a)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.closePath(); ctx.stroke(); break
        case "gift":
            rrect(ctx, 5, 11.8, 14, 7.6, 1.6); ctx.stroke()
            rrect(ctx, 4, 8.2, 16, 3.6, 1.6); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 8.2); ctx.lineTo(12, 19.4); ctx.stroke()
            ctx.beginPath(); ctx.arc(9.3, 6.3, 2.0, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(14.7, 6.3, 2.0, 0, Math.PI * 2); ctx.stroke()
            break
        case "chart":
            ctx.lineWidth = root.strokeW + 0.9
            ctx.beginPath()
            ctx.moveTo(7, 16.5); ctx.lineTo(7, 10.5)
            ctx.moveTo(12, 16.5); ctx.lineTo(12, 6)
            ctx.moveTo(17, 16.5); ctx.lineTo(17, 13)
            ctx.stroke()
            ctx.lineWidth = root.strokeW
            ctx.beginPath(); ctx.moveTo(4.5, 19.5); ctx.lineTo(19.5, 19.5); ctx.stroke()
            break
        case "gear":
            ctx.beginPath(); ctx.arc(12, 12, 3.4, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath()
            for (i = 0; i < 8; i++) {
                a = i * Math.PI / 4
                ctx.moveTo(12 + 6.4 * Math.cos(a), 12 + 6.4 * Math.sin(a))
                ctx.lineTo(12 + 9.2 * Math.cos(a), 12 + 9.2 * Math.sin(a))
            }
            ctx.stroke(); break
        case "search":
            ctx.beginPath(); ctx.arc(10.6, 10.6, 5.4, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(14.8, 14.8); ctx.lineTo(19.2, 19.2); ctx.stroke()
            break
        case "bell":
            ctx.beginPath()
            ctx.moveTo(6.4, 15.6); ctx.lineTo(6.4, 10.8)
            ctx.quadraticCurveTo(6.4, 4.6, 12, 4.6)
            ctx.quadraticCurveTo(17.6, 4.6, 17.6, 10.8)
            ctx.lineTo(17.6, 15.6)
            ctx.closePath(); ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 17.8, 1.9, 0.12 * Math.PI, 0.88 * Math.PI); ctx.stroke()
            break
        case "plus":
            ctx.moveTo(12, 5); ctx.lineTo(12, 19)
            ctx.moveTo(5, 12); ctx.lineTo(19, 12)
            ctx.stroke(); break
        case "minus":
            ctx.moveTo(5, 12); ctx.lineTo(19, 12)
            ctx.stroke(); break
        case "close":
            ctx.moveTo(6.4, 6.4); ctx.lineTo(17.6, 17.6)
            ctx.moveTo(17.6, 6.4); ctx.lineTo(6.4, 17.6)
            ctx.stroke(); break
        case "check":
            ctx.moveTo(5.5, 12.5); ctx.lineTo(10, 17); ctx.lineTo(18.5, 7.5)
            ctx.stroke(); break
        case "sparkle":
            ctx.moveTo(12, 3.6)
            ctx.quadraticCurveTo(13, 11, 20.4, 12)
            ctx.quadraticCurveTo(13, 13, 12, 20.4)
            ctx.quadraticCurveTo(11, 13, 3.6, 12)
            ctx.quadraticCurveTo(11, 11, 12, 3.6)
            ctx.closePath(); ctx.fill(); break
        case "user":
            ctx.beginPath(); ctx.arc(12, 8.8, 3.7, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(5.6, 19.6)
            ctx.quadraticCurveTo(6.4, 14.2, 12, 14.2)
            ctx.quadraticCurveTo(17.6, 14.2, 18.4, 19.6)
            ctx.stroke(); break
        case "sliders":
            ctx.beginPath()
            ctx.moveTo(4.2, 8); ctx.lineTo(19.8, 8)
            ctx.moveTo(4.2, 16); ctx.lineTo(19.8, 16)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(9.4, 8, 2.1, 0, Math.PI * 2); ctx.fill(); ctx.stroke()
            ctx.beginPath(); ctx.arc(14.6, 16, 2.1, 0, Math.PI * 2); ctx.fill(); ctx.stroke()
            break
        case "dot":
            ctx.beginPath(); ctx.arc(6, 12, 1.4, 0, Math.PI * 2); ctx.fill()
            ctx.beginPath(); ctx.arc(12, 12, 1.4, 0, Math.PI * 2); ctx.fill()
            ctx.beginPath(); ctx.arc(18, 12, 1.4, 0, Math.PI * 2); ctx.fill()
            break
        case "trophy":
            ctx.beginPath()
            ctx.moveTo(8.2, 5); ctx.lineTo(15.8, 5); ctx.lineTo(15.8, 9.8)
            ctx.arc(12, 9.8, 3.8, 0, Math.PI)
            ctx.closePath(); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 13.8); ctx.lineTo(12, 16.6); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(8, 19); ctx.lineTo(16, 19); ctx.stroke()
            break
        case "sun":
            ctx.beginPath(); ctx.arc(12, 12, 4.2, 0, Math.PI * 2); ctx.stroke()
            for (var s = 0; s < 8; s++) {
                a = s * Math.PI / 4
                ctx.moveTo(12 + 6.6 * Math.cos(a), 12 + 6.6 * Math.sin(a))
                ctx.lineTo(12 + 8.8 * Math.cos(a), 12 + 8.8 * Math.sin(a))
            }
            ctx.stroke(); break
        case "moon":
            // 月牙：大圆填充 + 偏移圆挖空
            ctx.beginPath(); ctx.arc(12, 12, 7.6, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath(); ctx.arc(15.4, 10.4, 6.4, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalCompositeOperation = "source-over"
            break
        default:
            break
        }
    }
}
