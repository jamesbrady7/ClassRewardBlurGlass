import QtQuick

// 姓名显示/隐藏开关。
//
// 重绘要点（用户要求"更高级、简约、表意明确"，且底色统一白、不描边）：
//   · 底色：半透明白玻璃 #55ffffff / 悬停 #a8ffffff —— 与商店那排图标钮（IconChip 默认）
//     同一档；**不画描边**（原来悬停时有一圈 #cfe9e2 的边）
//   · 图标：原来那版是"大瞳孔 + 上下睫毛 + 高光"，偏可爱，小尺寸下糊成一团。
//     现在只留两样东西 —— **杏仁轮廓 + 瞳孔**；隐藏态加一道**斜杠**（通用"不可见"符号），
//     一眼就知道当前是"看不见名字"还是"看得见"。
Item {
    id: root

    property bool eyeOpen: true       // true=睁眼（显示姓名）
    signal clicked()

    onEyeOpenChanged: eyeCanvas.requestPaint()

    width: 36
    height: 36

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ma.containsMouse ? "#a8ffffff" : "#55ffffff"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Canvas {
        id: eyeCanvas
        anchors.centerIn: parent
        width: 22
        height: 16
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            // 杏仁轮廓：上下两条对称的二次曲线。
            // 控制点离中线 k → 镜片高度正好是 k（二次贝塞尔在 t=0.5 的偏移是控制点偏移的一半，
            // 上下各一半，合成 k）。原来 k=7、宽 19 → 2.7:1 太扁，现在 k=11 → 1.7:1。
            var cy = 8, k = 11
            // 显示姓名时**整体同色**（原来轮廓 textSecondary、瞳孔 textPrimary，两种色）；
            // 隐藏态保持原样（轮廓/瞳孔 textMuted，斜杠 textPrimary）。
            var ink = root.eyeOpen ? Theme.textSecondary : Theme.textMuted
            ctx.strokeStyle = ink
            ctx.lineWidth = 1.6
            ctx.beginPath()
            ctx.moveTo(1.5, cy)
            ctx.quadraticCurveTo(11, cy - k, 20.5, cy)
            ctx.quadraticCurveTo(11, cy + k, 1.5, cy)
            ctx.closePath()
            ctx.stroke()

            // 瞳孔：边缘刚好**触及上下眼线**。
            //   中线处镜片高度 = k = 11（二次曲线 t=0.5 的偏移是控制点的一半，上下各 k/2）；
            //   描边 1.6 居中压在路径上，两侧各占 0.8 → 内缘间距 11 - 1.6 = 9.4
            //   → 半径 9.4/2 = 4.7 时正好贴上内缘（原来 3.1 太小，像个小黑点）。
            ctx.fillStyle = ink
            ctx.beginPath()
            ctx.arc(11, cy, 4.7, 0, Math.PI * 2)
            ctx.fill()

            // 隐藏态：一道斜杠压过整只眼（通用"不可见"符号）
            if (!root.eyeOpen) {
                ctx.strokeStyle = Theme.textPrimary
                ctx.lineWidth = 1.8
                ctx.beginPath()
                ctx.moveTo(4.0, 14.4)
                ctx.lineTo(18.0, 1.6)
                ctx.stroke()
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
