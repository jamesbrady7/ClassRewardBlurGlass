import QtQuick
import "../components"

// 批量操作：勾选学生徽章，一次性加减分
Column {
    id: root

    property string sel: ""          // 逗号分隔的学生 id
    property string cat: ""
    function contains(id) { return root.sel.split(',').indexOf(id) >= 0 }
    function toggle(id) {
        var arr = root.sel ? root.sel.split(',') : []
        var idx = arr.indexOf(id)
        if (idx >= 0) arr.splice(idx, 1); else arr.push(id)
        root.sel = arr.join(',')
    }

    spacing: Theme.spacing

    Row {
        width: parent.width
        spacing: 10
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "批量操作"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 1; height: 1 }
    }

    // 学生徽章网格（带淡色底）
    Card {
        width: parent.width
        height: 170
        radius: Theme.radius
        cardColor: "#e9eff7"
        Flickable {
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: grid.implicitWidth
            contentHeight: grid.implicitHeight
            clip: true
            Flow {
                id: grid
                width: parent.width
                spacing: 6
                Repeater {
                    model: reward.students
                    delegate: Rectangle {
                        id: badge
                        property bool hov: false
                        property bool sel: root.contains(modelData.id)
                        width: 56; height: 48
                        radius: Theme.radiusSmall
                        // 选中=整块主色实底填充；未选中=白底，与面板 #e9eff7 明显区分
                        color: badge.sel ? Theme.accent : (badge.hov ? "#f4f8ff" : Theme.surface)
                        border.color: badge.sel ? Theme.accentDark : Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                text: modelData.studentId
                                color: badge.sel ? "#c9f3ea" : Theme.textMuted
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: modelData.name.length > 3 ? modelData.name.slice(0, 3) : modelData.name
                                color: badge.sel ? "#ffffff" : Theme.textPrimary
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        // 选中角标：右上角白圆 + 翡翠 ✓
                        Rectangle {
                            visible: badge.sel
                            width: 13; height: 13; radius: 7
                            color: "#ffffff"
                            anchors.top: parent.top; anchors.topMargin: 2
                            anchors.right: parent.right; anchors.rightMargin: 2
                            Canvas {
                                width: 13; height: 13
                                anchors.centerIn: parent
                                onPaint: {
                                    var c = getContext("2d"); c.reset()
                                    c.strokeStyle = Theme.accent
                                    c.lineWidth = 1.8
                                    c.lineCap = "round"
                                    c.beginPath()
                                    c.moveTo(3.6, 7); c.lineTo(5.8, 9.2); c.lineTo(9.6, 4)
                                    c.stroke()
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: badge.hov = true
                            onExited: badge.hov = false
                            onClicked: root.toggle(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // 控制栏（带淡蓝底色 + 彩色按钮区分）
    Card {
        width: parent.width
        height: 56
        radius: Theme.radius
        cardColor: "#eef3fb"
        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            CuteButton { tone: "blue"; text: "全选"; anchors.verticalCenter: parent.verticalCenter; onClicked: { root.sel = reward.students.map(function(s) { return s.id }).join(',') } }
            CuteButton { text: "取消全选"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.sel = "" }
            Item { width: 4; height: 1 }
            Text { text: "分值"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
            Stepper { id: points; value: 1; max: 999; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 4; height: 1 }
            RoundBtn { size: 34; bg: Theme.accent; fg: "#ffffff"; icon: "plus"; hint: "按分值给所选学生加分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.op(true) }
            RoundBtn { size: 34; bg: Theme.pink; fg: "#ffffff"; icon: "minus"; hint: "按分值给所选学生扣分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.op(false) }
            Item { width: 4; height: 1 }
            Pill {
                text: "已选 " + (root.sel ? root.sel.split(',').length : 0) + " 人"
                bg: Theme.accentSoft; fg: Theme.accentDark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 维度
    Row {
        width: parent.width
        spacing: 6
        Text { text: "操作分类："; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
        Repeater {
            model: reward.categories
            delegate: CuteButton {
                tone: root.cat === modelData ? "soft" : "secondary"
                text: modelData
                onClicked: root.cat = modelData
            }
        }
    }

    function op(isAdd) {
        if (!root.sel) { mainWin.toast.show("请先点选要操作的学生", 2000, true); return }
        if (!root.cat) { mainWin.toast.show("请先选择操作分类标签，再进行" + (isAdd ? "加分" : "扣分"), 2000, true); return }
        mainWin.toast.show(reward.batchPointChange(root.sel, points.value, isAdd, root.cat))
        root.sel = ""
    }
}
