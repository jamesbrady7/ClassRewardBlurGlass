import QtQuick

// 小图标按钮：Canvas 线框图标（＋可选文字）。
// 图标用矢量绘制，不依赖任何 emoji/符号字体。
// icon: undo(左回箭头) | clock(时钟) | bag(背包)
// 不传 text 时收成**圆形纯图标按钮**（宽度=高度、无描边留白）。
Rectangle {
    id: root

    property string icon: "undo"
    property string text: ""
    property color fg: Theme.textSecondary
    property color bg: Theme.bgTop
    property bool bordered: true        // 彩色软底靠描边分层；白玻璃按钮不需要（同奖券的删除钮）
    // 悬停/按压提亮。⚠️ 白玻璃底（#55ffffff 之类）**提不动**——Qt.lighter 对已饱和的白色是恒等变换，
    // 光靠上面那个 gradient 悬停没有任何变化，必须叠一层白。
    property bool hoverHighlight: false
    signal clicked()

    readonly property bool iconOnly: text === ""
    radius: root.iconOnly ? height / 2 : Theme.radiusSmall
    height: 36
    width: root.iconOnly ? height : (iconItem.implicitWidth + 12 + lab.implicitWidth + 26)
    gradient: Gradient {
        GradientStop { position: 0.0; color: mouse.containsMouse ? Qt.lighter(root.bg, 1.32) : Qt.lighter(root.bg, 1.16) }
        GradientStop { position: 1.0; color: mouse.pressed ? Qt.lighter(root.bg, 0.88) : root.bg }
    }
    border.color: root.bordered ? Qt.lighter(root.bg, 0.8) : "transparent"
    border.width: root.bordered ? 1 : 0

    // 悬停/按压高亮层：**必须压在图标下面**（先声明在前），否则把图标一起洗白
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.hoverHighlight
        color: "#ffffff"
        opacity: mouse.pressed ? 0.55 : (mouse.containsMouse ? 0.30 : 0)
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Canvas {
            id: iconItem
            width: 16
            height: 16
            onPaint: {
                var c = getContext("2d")
                c.reset()
                c.strokeStyle = root.fg
                c.lineWidth = 1.7
                c.lineCap = "round"
                c.lineJoin = "round"
                if (root.icon === "clock") {
                    // 表盘
                    c.beginPath()
                    c.arc(8, 8, 5.1, 0, Math.PI * 2)
                    c.stroke()
                    // 指针
                    c.beginPath()
                    c.moveTo(8, 5.1)
                    c.lineTo(8, 8)
                    c.lineTo(10.5, 9.5)
                    c.stroke()
                } else if (root.icon === "bag") {
                    // 提手
                    c.beginPath()
                    c.arc(8, 6.4, 2.0, Math.PI, 0, false)
                    c.stroke()
                    // 包身
                    c.beginPath()
                    c.moveTo(4.0, 6.4)
                    c.lineTo(4.0, 12.6)
                    c.quadraticCurveTo(4.0, 13.4, 4.8, 13.4)
                    c.lineTo(11.2, 13.4)
                    c.quadraticCurveTo(12.0, 13.4, 12.0, 12.6)
                    c.lineTo(12.0, 6.4)
                    c.stroke()
                    // 兜盖
                    c.beginPath()
                    c.moveTo(4.0, 8.9)
                    c.lineTo(12.0, 8.9)
                    c.stroke()
                } else {
                    // undo / 回退：左箭头
                    c.beginPath()
                    c.moveTo(12.6, 8.4)
                    c.lineTo(5.0, 8.4)                 // 杆
                    c.moveTo(7.6, 6.0)
                    c.lineTo(5.0, 8.4)                 // 上箭头
                    c.moveTo(7.6, 10.8)
                    c.lineTo(5.0, 8.4)                 // 下箭头
                    c.stroke()
                }
            }
        }

        Text {
            id: lab
            text: root.text
            color: root.fg
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
