import QtQuick

// 眼睛按钮：睁眼（显示姓名）/ 闭眼（隐藏姓名）。
// 睁眼=大眼睛 + 大瞳孔高光 + 上下睫毛；闭眼=笑弧 + 眼角睫毛。
Item {
    id: root

    property bool eyeOpen: true       // true=睁眼（显示姓名）
    signal clicked()

    onEyeOpenChanged: eyeCanvas.requestPaint()

    width: 36
    height: 36

    Rectangle {
        id: bg
        property bool hov: false
        width: parent.width
        height: parent.height
        radius: width / 2
        color: hov ? Theme.accentSoft : "transparent"
        border.color: hov ? "#c9d9e8" : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }

        Canvas {
            id: eyeCanvas
            anchors.centerIn: parent
            width: 28
            height: 18
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var pen = Theme.textSecondary
                ctx.lineCap = "round"

                if (root.eyeOpen) {
                    // ---- 睁眼：眼形 + 大瞳孔 ----
                    ctx.lineWidth = 1.5
                    ctx.strokeStyle = pen
                    // 眼形（杏仁轮廓）
                    ctx.beginPath()
                    ctx.ellipse(4.6, 3.0, 18.8, 12.0)
                    ctx.stroke()
                    // 眼线：沿上眼睑压一道深色眼线，外眼角微上挑
                    ctx.strokeStyle = Theme.textPrimary
                    ctx.lineWidth = 1.7
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(6.4, 5.6)
                    ctx.quadraticCurveTo(14.0, 2.7, 20.6, 4.9)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(20.6, 4.8)
                    ctx.quadraticCurveTo(22.2, 3.7, 23.2, 2.6)
                    ctx.stroke()
                    ctx.strokeStyle = pen
                    // 大瞳孔（偏上方，占满眼眶大半）
                    ctx.fillStyle = Theme.textPrimary
                    ctx.beginPath()
                    ctx.ellipse(9.2, 5.0, 10.0, 9.6)
                    ctx.fill()
                    // 高光（两粒，让眼睛有神）
                    ctx.fillStyle = "#ffffff"
                    ctx.beginPath()
                    ctx.ellipse(10.8, 7.0, 2.6, 3.0)
                    ctx.fill()
                    ctx.beginPath()
                    ctx.ellipse(15.4, 10.8, 1.4, 1.7)
                    ctx.fill()
                    // 睫毛：沿上眼睑椭圆弧均匀分布 7 根（参数等角取样，长度一致）
                    ctx.strokeStyle = pen
                    ctx.lineWidth = 1.3
                    var ex = 14, ey = 9, erx = 9.4, ery = 6.0
                    for (var i = 0; i < 7; i++) {
                        var th = Math.PI + (i + 0.5) * (Math.PI / 7)   // 覆盖整个上眼睑弧
                        var bx2 = ex + erx * Math.cos(th)
                        var by2 = ey + ery * Math.sin(th)
                        var nx2 = Math.cos(th) / erx, ny2 = Math.sin(th) / ery
                        var nl = Math.sqrt(nx2 * nx2 + ny2 * ny2) || 1
                        nx2 /= nl; ny2 /= nl
                        ctx.beginPath()
                        ctx.moveTo(bx2 - nx2 * 0.9, by2 - ny2 * 0.9)
                        ctx.lineTo(bx2 + nx2 * 3.1, by2 + ny2 * 3.1)
                        ctx.stroke()
                    }
                } else {
                    // ---- 闭眼：弯弯的笑弧 + 眼角睫毛 ----
                    ctx.lineWidth = 1.6
                    ctx.strokeStyle = pen
                    ctx.beginPath()
                    ctx.moveTo(5.4, 7.4)
                    ctx.quadraticCurveTo(14, 14.2, 22.6, 7.4)
                    ctx.stroke()
                    // 睫毛：沿笑弧均匀分布 7 根（法线向上，向两侧自然外张）
                    ctx.lineWidth = 1.3
                    for (var j = 0; j < 7; j++) {
                        var u = j / 6
                        var om = 1 - u
                        var qx = om * om * 5.4 + 2 * u * om * 14 + u * u * 22.6
                        var qy = om * om * 7.4 + 2 * u * om * 14.2 + u * u * 7.4
                        var txx = -2 * om * 5.4 + (2 - 4 * u) * 14 + 2 * u * 22.6
                        var tyy = -2 * om * 7.4 + (2 - 4 * u) * 14.2 + 2 * u * 7.4
                        var tl = Math.sqrt(txx * txx + tyy * tyy) || 1
                        // 向下一侧法线（闭眼时睫毛朝下贴下眼睑方向）
                        var nx3 = tyy / tl, ny3 = -txx / tl
                        if (ny3 < 0) { nx3 = -nx3; ny3 = -ny3 }
                        ctx.beginPath()
                        ctx.moveTo(qx + nx3 * 0.7, qy + ny3 * 0.7)
                        ctx.lineTo(qx + nx3 * 3.9, qy + ny3 * 3.9)
                        ctx.stroke()
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: bg.hov = true
            onExited: bg.hov = false
            onClicked: root.clicked()
        }
    }
}
