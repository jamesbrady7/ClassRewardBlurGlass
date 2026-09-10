import QtQuick
import QtQuick.Controls

// 立体圆形按钮：垂直渐变 + 底部投影 + 按压缩放。
// icon 用 Canvas 矢量绘制（undo/plus/minus/search/clock/bag/trash），glyph 为字符兜底（emoji 等）。
Item {
    id: root

    property int size: 34
    property color bg: Theme.bgTop
    property color fg: Theme.textSecondary
    property string icon: ""          // undo | plus | minus | search | clock | bag | trash
    property string glyph: ""         // 未提供 icon 时显示的字符
    property real iconSpan: 16        // 图标画布边长（越大图形越大）
    property real iconWeight: 1.6     // 线宽
    property color borderOverride: "transparent"   // 指定外圈描边色
    property real borderW: 1
    property string hint: ""                       // 悬停说明文字
    property real glyphSize: root.size <= 30 ? 14 : 15
    signal clicked()

    width: root.size
    height: root.size

    // 底部柔和投影（让按钮"浮"起来）
    Rectangle {
        width: root.size
        height: root.size
        radius: root.size / 2
        color: "#26000000"
        y: 2
    }

    Rectangle {
        id: disc
        anchors.fill: parent
        radius: root.size / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Qt.lighter(root.bg, 1.14), 0.72) }
            GradientStop { position: 1.0; color: Qt.alpha(root.bg, 0.88) }
        }
        border.color: root.borderOverride !== "transparent" ? root.borderOverride
                     : mouse.pressed ? Qt.darker(root.bg, 1.18)
                     : mouse.containsMouse ? root.fg
                     : Qt.lighter(root.bg, 1.06)
        border.width: root.borderOverride !== "transparent"
                     ? (mouse.containsMouse ? 2.8 : root.borderW)
                     : (mouse.containsMouse ? 1.7 : root.borderW)
        scale: mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.07 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on border.width { NumberAnimation { duration: 120 } }

        Canvas {
            visible: root.icon !== ""
            anchors.centerIn: parent
            width: root.iconSpan
            height: width
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = root.fg
                ctx.lineWidth = root.iconWeight
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                var u = width / 16   // 以 16 单位坐标，随画布缩放
                function l(x1, y1, x2, y2) { ctx.moveTo(x1*u, y1*u); ctx.lineTo(x2*u, y2*u) }
                ctx.beginPath()
                if (root.icon === "plus") {
                    l(8, 3.4, 8, 12.6); l(3.4, 8, 12.6, 8)
                } else if (root.icon === "minus") {
                    l(3.6, 8, 12.4, 8)
                } else if (root.icon === "undo") {
                    l(12.6, 8.4, 5.0, 8.4)
                    l(7.6, 6.0, 5.0, 8.4); l(7.6, 10.8, 5.0, 8.4)
                } else if (root.icon === "search") {
                    ctx.beginPath()
                    ctx.arc(7.0*u, 7.0*u, 4.4*u, 0, Math.PI * 2)
                    ctx.moveTo(10.4*u, 10.4*u); ctx.lineTo(13.4*u, 13.4*u)
                } else if (root.icon === "clock") {
                    ctx.arc(8*u, 8*u, 5.2*u, 0, Math.PI * 2)
                    l(8, 5.1, 8, 8); l(8, 8, 10.6, 9.6)
                } else if (root.icon === "bag") {
                    ctx.moveTo(5.2*u, 6.6*u); ctx.lineTo(10.8*u, 6.6*u)
                    ctx.moveTo(6.6*u, 6.6*u); ctx.lineTo(6.6*u, 4.9*u)
                    ctx.lineTo(9.4*u, 4.9*u); ctx.lineTo(9.4*u, 6.6*u)
                    ctx.moveTo(4.0*u, 6.6*u); ctx.lineTo(4.0*u, 11.8*u)
                    ctx.lineTo(12.0*u, 11.8*u); ctx.lineTo(12.0*u, 6.6*u)
                } else if (root.icon === "move") {
                    // 移组：箭头进入右端组箱
                    l(2.6, 8.8, 7.4, 8.8)
                    l(6.0, 6.8, 7.4, 8.8); l(6.0, 10.8, 7.4, 8.8)
                    l(9.0, 5.6, 9.0, 12.2); l(9.0, 12.2, 13.6, 12.2)
                    l(13.6, 12.2, 13.6, 5.6); l(13.6, 5.6, 9.0, 5.6)
                } else if (root.icon === "trash") {
                    l(4.2, 5.6, 11.8, 5.6)
                    l(6.9, 3.6, 9.1, 3.6)
                    l(6.2, 5.6, 6.6, 12.4); l(9.8, 5.6, 9.4, 12.4)
                    l(12.0, 12.4, 4.0, 12.4)
                }
                ctx.stroke()
            }
        }

        Text {
            visible: root.icon === ""
            text: root.glyph
            anchors.centerIn: parent
            color: root.fg
            font.pixelSize: root.glyphSize
            font.family: Theme.fontFamily
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }

    // 无边框小号悬停说明（系统覆盖层，不被列表裁剪）
    ToolTip {
        id: tt
        visible: root.hint !== "" && mouse.containsMouse
        delay: 300
        timeout: 3500
        text: root.hint
        leftPadding: 10
        rightPadding: 10
        topPadding: 5
        bottomPadding: 5
        background: Rectangle { color: "#eef2f7"; radius: 6; border.width: 0 }
        contentItem: Text {
            text: tt.text
            color: "#3a4654"
            font.pixelSize: 11
            font.family: Theme.fontFamily
        }
        // 丝滑淡入淡出
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 110; easing.type: Easing.InCubic }
        }
        onVisibleChanged: {
            if (visible) { posTimer.tries = 0; posTimer.restart() }
        }
    }
    // Popup 坐标相对按钮自身：量出宽高后水平居中、放到按钮正上方
    Timer {
        id: posTimer
        interval: 40
        repeat: true
        property int tries: 0
        onTriggered: {
            if (!tt.visible) { posTimer.stop(); return }
            if (tt.width < 4 && posTimer.tries < 8) { posTimer.tries++; return }
            tt.x = Math.round((root.width - tt.width) / 2)
            tt.y = Math.round(-tt.height - 8)
            posTimer.stop()
        }
    }
}
