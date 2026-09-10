import QtQuick

// 左侧纵向导航：白色圆角卡片。选中态=一颗无边框「漂浮胶囊」随选项滑动，
// 移动时轻微挤压回弹；序号与文字单层就地变色/缩放（无双层交叠的虚影），节奏统一。
Item {
    id: root

    property var titles: []
    property int currentIndex: 0
    signal activated(int index)

    readonly property real rowH: 46
    readonly property real rowGap: 6
    readonly property real topPad: 12

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
    }

    // ===== 漂浮胶囊：选中框 + 左竖条一体滑动 =====
    Rectangle {
        id: selPill
        objectName: "selPill"
        property bool settled: false
        x: 12
        width: parent.width - 24
        height: rowH
        y: topPad + Math.max(0, root.currentIndex) * (rowH + rowGap)
        radius: Theme.radiusSmall
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#e2f4ee" }
            GradientStop { position: 1.0; color: "#cfece2" }
        }
        transform: Scale { id: pillSquish; xScale: 1; yScale: 1 }
        Component.onCompleted: settled = true

        Behavior on y {
            NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
        }
        onYChanged: if (settled) glide.restart()

        // 果冻节奏：起步挤压 → 途中微过拉伸长 → 落定回正（与 y 的 320ms 同步）
        SequentialAnimation {
            id: glide
            ParallelAnimation {
                NumberAnimation { target: pillSquish; property: "xScale"; to: 0.965; duration: 110; easing.type: Easing.InQuad }
                NumberAnimation { target: pillSquish; property: "yScale"; to: 0.93;  duration: 110; easing.type: Easing.InQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: pillSquish; property: "xScale"; to: 1.02; duration: 130; easing.type: Easing.OutSine }
                NumberAnimation { target: pillSquish; property: "yScale"; to: 1.04; duration: 130; easing.type: Easing.OutSine }
            }
            ParallelAnimation {
                NumberAnimation { target: pillSquish; property: "xScale"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { target: pillSquish; property: "yScale"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
            }
        }

        // 前导竖条（胶囊的子件，一体移动；软圆角无硬边）
        Rectangle {
            width: 4; height: 18; radius: 2
            color: Theme.accent
            anchors.left: parent.left
            anchors.leftMargin: -7
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0.9
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.topPad
        anchors.rightMargin: root.topPad
        anchors.top: parent.top
        anchors.topMargin: root.topPad
        spacing: root.rowGap

        Repeater {
            model: root.titles
            delegate: Item {
                id: box
                property bool sel: index === root.currentIndex
                property bool hov: false
                width: parent.width
                height: root.rowH

                // 悬停淡底（选中行不叠加，胶囊自带反馈）
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: "#f3f8f6"
                    opacity: box.hov && !box.sel ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // 序号方块：底色渐变过渡 + 数字颜色/缩放就地动效
                    Item {
                        width: 26; height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: box.sel ? Theme.accent : (box.hov ? "#bfe6d9" : "#d9efe8")
                            Behavior on color { ColorAnimation { duration: 240 } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            color: box.sel ? "#ffffff" : Theme.textSecondary
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                            font.family: Theme.fontFamily
                            scale: box.sel ? 1.14 : (box.hov ? 1.06 : 1.0)
                            Behavior on color { ColorAnimation { duration: 240 } }
                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                        }
                    }

                    // 板块名：颜色 + 放大（选中明显、悬停次之），随胶囊同步
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: box.sel ? Theme.accentDark : (box.hov ? "#2c8f77" : Theme.textSecondary)
                        font.pixelSize: 14
                        font.bold: box.sel
                        font.family: Theme.fontFamily
                        scale: box.sel ? 1.14 : (box.hov ? 1.06 : 1.0)
                        transformOrigin: Item.Center
                        Behavior on color { ColorAnimation { duration: 240 } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: box.hov = true
                    onExited: box.hov = false
                    onClicked: root.activated(index)
                }
            }
        }
    }
}
