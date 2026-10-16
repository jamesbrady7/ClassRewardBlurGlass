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
        height: 15
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            // 杏仁轮廓：上下两条对称的二次曲线
            ctx.strokeStyle = root.eyeOpen ? Theme.textSecondary : Theme.textMuted
            ctx.lineWidth = 1.6
            ctx.beginPath()
            ctx.moveTo(1.5, 7.5)
            ctx.quadraticCurveTo(11, 0.5, 20.5, 7.5)
            ctx.quadraticCurveTo(11, 14.5, 1.5, 7.5)
            ctx.closePath()
            ctx.stroke()

            // 瞳孔
            ctx.fillStyle = root.eyeOpen ? Theme.textPrimary : Theme.textMuted
            ctx.beginPath()
            ctx.arc(11, 7.5, 2.7, 0, Math.PI * 2)
            ctx.fill()

            // 隐藏态：一道斜杠压过整只眼
            if (!root.eyeOpen) {
                ctx.strokeStyle = Theme.textPrimary
                ctx.lineWidth = 1.8
                ctx.beginPath()
                ctx.moveTo(4.2, 12.9)
                ctx.lineTo(17.8, 2.1)
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
