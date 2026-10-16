import QtQuick

// 对话框里的「标签 + 输入框」字段
Column {
    id: root

    property string label: ""
    property alias text: input.text
    property alias input: input

    spacing: 5
    width: parent ? parent.width : 300

    Text {
        text: root.label
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily
    }
    Rectangle {
        id: box
        width: root.width
        height: 38
        radius: Theme.radiusSmall
        // 底色：静息=半透明白玻璃，聚焦=提亮 —— 与积分商店搜索栏同一档
        // ⚠️ 静息不能再是 Theme.surface（纯白不透明）：那样"聚焦提亮"就没地方可提了，
        //    高亮必须靠静息态压暗来换取对比。
        color: input.activeFocus ? "#e0ffffff" : "#55ffffff"
        // **不要边框**：原来聚焦时画 1px 强调色硬边，在这一片浅色玻璃上会读成"框了一条线"。
        // 聚焦的提示改由下面那圈"向内渐隐的内阴影"承担（同搜索栏展开态）。
        border.width: 0
        Behavior on color { ColorAnimation { duration: 140 } }

        // 静息：边缘**向内渐隐的白边**
        // 多层内缩的圆角描边叠出衰减（本 Qt 的 Canvas 没有高斯模糊，只能这样近似）。
        // 每条描边都从 box 内侧起画，不会溢出容器。
        Canvas {
            anchors.fill: parent
            visible: !input.activeFocus
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height, base = box.radius, N = 5
                for (var i = 0; i < N; i++) {
                    var a = 0.58 * Math.pow(1 - i / N, 1.4)      // 贴边最亮，向内快速衰减
                    var ins = i + 1
                    var x = ins, y = ins, ww = w - 2 * ins, hh = h - 2 * ins
                    var rr = Math.max(1, base - ins)
                    ctx.strokeStyle = "rgba(255,255,255," + a.toFixed(3) + ")"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(x + rr, y)
                    ctx.lineTo(x + ww - rr, y); ctx.quadraticCurveTo(x + ww, y, x + ww, y + rr)
                    ctx.lineTo(x + ww, y + hh - rr); ctx.quadraticCurveTo(x + ww, y + hh, x + ww - rr, y + hh)
                    ctx.lineTo(x + rr, y + hh); ctx.quadraticCurveTo(x, y + hh, x, y + hh - rr)
                    ctx.lineTo(x, y + rr); ctx.quadraticCurveTo(x, y, x + rr, y)
                    ctx.closePath()
                    ctx.stroke()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // 聚焦：由边缘**向内渐隐**的内阴影（内凹感），约 55% 处消失
        // 声明在 TextInput 之前 = 压在文字下面，不会糊到输入内容
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, box.radius - 1)
            visible: opacity > 0.01
            opacity: input.activeFocus ? 1 : 0
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(0.35, 0.40, 0.50, 0.15) }
                GradientStop { position: 0.55; color: Qt.rgba(0.35, 0.40, 0.50, 0.0) }
            }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: Text.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
            clip: true
        }
    }
}
