import QtQuick

// 全站统一的搜索框：**全圆胶囊** + 放大镜 + 半透明白玻璃底 + 向内渐隐的白边。
// 提取自 StudentPicker 原本内联的那一份 —— 花名册/商店/数据分析要长得一样，
// 就不能各写一份（改一处漏三处）。
//
// 用法：
//   SearchBox { width: 240; placeholder: "搜索姓名或学号…"
//               onTextEdited: myFilter(text) }
// active=true 表示"展开/聚焦"态（提亮 + 灰边 + 内阴影），由调用方控制。
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: "搜索…"
    property string doneLabel: ""        // 非空时优先显示（如 "✓ 陈果"），替掉 placeholder
    property bool active: false          // 展开/聚焦态
    signal textEdited(string t)
    signal accepted()
    signal clicked()
    signal cleared()          // 点了右侧「×」：文字已清空，调用方再收拾自己的状态

    width: 240
    height: 38

    // 输入区左右留白：左边给放大镜、右边给清除位
    readonly property int _leftPad: 34
    // 右侧留白：默认给"×"；调用方可以再加大（比如在学生名字后塞操作按钮）
    property int extraRightPad: 0
    readonly property int _rightPad: 36 + extraRightPad

    Rectangle {
        id: box
        anchors.fill: parent
        radius: Theme.radiusPill
        // 半透明白玻璃；悬停提亮、展开更亮（三档与同排图标钮一致）
        color: root.active ? "#e0ffffff" : (boxMa.containsMouse ? "#a8ffffff" : "#55ffffff")
        // 只有展开态用硬边；平时交给下面那圈"向内渐隐的白边"
        border.color: Theme.textMuted
        border.width: root.active ? 1 : 0
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // 静息：边缘向内渐隐的白边（多层内缩圆角描边叠出衰减；本 Qt 的 Canvas 没有高斯模糊）
        Canvas {
            anchors.fill: parent
            visible: !root.active
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height, base = box.radius, N = 5
                for (var i = 0; i < N; i++) {
                    var a = 0.58 * Math.pow(1 - i / N, 1.4)
                    var ins = i + 1
                    var x = ins, y = ins, ww = w - 2 * ins, hh = h - 2 * ins
                    // ⚠️ 圆角必须钳到 min(ww,hh)/2：radius 是 radiusPill(999) 时，
                    //    `base - ins` 远大于半个框，二次贝塞尔路径会画反、形状直接崩掉。
                    var rr = Math.max(1, Math.min(base, ww / 2, hh / 2))
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

        // 展开：由边缘向内渐隐的内阴影（内凹感），约 55% 处消失
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, Math.min(box.radius, (box.height - 2) / 2))
            visible: opacity > 0.01
            opacity: root.active ? 1 : 0
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(0.35, 0.40, 0.50, 0.15) }
                GradientStop { position: 0.55; color: Qt.rgba(0.35, 0.40, 0.50, 0.0) }
            }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }

        // 放大镜
        Canvas {
            width: 15; height: 15
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                var c = getContext("2d"); c.reset()
                c.strokeStyle = Theme.textMuted
                c.lineWidth = 1.6
                c.lineCap = "round"
                c.beginPath()
                c.arc(6.2, 6.2, 4.2, 0, Math.PI * 2)
                c.moveTo(9.6, 9.6); c.lineTo(12.8, 12.8)
                c.stroke()
            }
        }

        Text {
            visible: root.doneLabel === "" && input.text.length === 0
            text: root.placeholder
            anchors.left: parent.left; anchors.leftMargin: root._leftPad
            anchors.right: parent.right; anchors.rightMargin: root._rightPad
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        Text {
            visible: root.doneLabel !== "" && input.text.length === 0
            text: root.doneLabel
            anchors.left: parent.left; anchors.leftMargin: root._leftPad
            anchors.right: parent.right; anchors.rightMargin: root._rightPad
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accentDark
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: root._leftPad
            anchors.rightMargin: root._rightPad
            verticalAlignment: Text.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
            clip: true
            onTextChanged: root.textEdited(input.text)
            onAccepted: root.accepted()
        }

        // 整框可点（hoverEnabled 供上面的底色高亮用）
        MouseArea {
            id: boxMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { input.forceActiveFocus(); root.clicked() }
        }

        // 右侧「×」：有内容（输入了字 或 有 doneLabel）才出现。
        // 只负责清掉文字，其余状态（选中项/模式）由调用方在 onCleared 里处理。
        Item {
            id: clearBtn
            width: 22; height: 22
            anchors.right: parent.right; anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length > 0 || root.doneLabel !== ""
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: clearMa.containsMouse ? "#3affffff" : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Canvas {
                anchors.centerIn: parent
                width: 10; height: 10
                onPaint: {
                    var c = getContext("2d"); c.reset()
                    c.strokeStyle = Theme.textMuted
                    c.lineWidth = 1.6
                    c.lineCap = "round"
                    c.beginPath()
                    c.moveTo(1, 1); c.lineTo(9, 9)
                    c.moveTo(9, 1); c.lineTo(1, 9)
                    c.stroke()
                }
            }
            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // 先清文字（会触发 textEdited），再发 cleared —— 调用方在 cleared 里做收尾
                onClicked: { input.text = ""; root.cleared() }
            }
        }
    }
}
