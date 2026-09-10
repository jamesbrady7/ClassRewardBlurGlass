import QtQuick

// 左侧纵向导航：白色圆角卡片，内排板块项。
// 每项内容（序号+文字）整体居中；高亮用恒定色+透明度/缩放，平滑无灰。
Item {
    id: root

    property var titles: []
    property int currentIndex: 0
    signal activated(int index)

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.glass
        border.color: Theme.glassBorder
        border.width: 1
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        spacing: 6

        Repeater {
            model: root.titles
            delegate: Rectangle {
                id: box
                property bool hov: false
                property bool on: index === root.currentIndex || hov
                width: parent.width
                height: 46
                radius: Theme.radiusSmall
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: index === root.currentIndex ? Theme.accentSoft : "#c8d8e6"
                    opacity: box.on ? 1 : 0
                    border.color: index === root.currentIndex ? "#9fd6c4" : "transparent"
                    border.width: index === root.currentIndex ? 2 : 0
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on border.width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    visible: index === root.currentIndex
                    width: 4; height: 20; radius: 2
                    color: Theme.accent
                    anchors.left: parent.left; anchors.leftMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 内容左排（留出足够内边距，不太贴左缘）
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // 序号
                    Item {
                        width: 26; height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: index === root.currentIndex ? Theme.accent : "#aec4d8"
                            opacity: box.on ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                        Text { // 平时
                            anchors.centerIn: parent
                            text: index + 1
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                            font.family: Theme.fontFamily
                            opacity: box.on ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                        Text { // 悬停/选中
                            anchors.centerIn: parent
                            text: index + 1
                            color: index === root.currentIndex ? "#ffffff" : "#3f5c7a"
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                            font.family: Theme.fontFamily
                            opacity: box.on ? 1 : 0
                            scale: index === root.currentIndex ? 1.12 : (hov ? 1.05 : 1.0)
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                        }
                    }

                    // 文字（平时/悬停/选中两态叠加，选中放大）
                    Item {
                        width: Math.max(txtIdle.implicitWidth, txtAct.implicitWidth)
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: txtIdle
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.textSecondary
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            opacity: box.on ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            id: txtAct
                            anchors.centerIn: parent
                            transformOrigin: Item.Center
                            text: modelData
                            color: index === root.currentIndex ? Theme.accentDark : "#4c6d92"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: Theme.fontFamily
                            opacity: box.on ? 1 : 0
                            scale: index === root.currentIndex ? 1.16 : (hov ? 1.08 : 1.0)
                            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
                        }
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
