import QtQuick
import "../components"

// 小组排行榜：顶部领奖台（纯展示前三名）；下方所有小组平铺成方块。
// 每块：组员学号姓名、可自填分值后加减；右键菜单 = 更改组名 / 删除小组。
Flickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight

    Column {
        id: col
        width: root.width
        spacing: 12

        // ===== 标题行（新建小组在右）=====
        Item {
            width: parent.width
            height: 40
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "小组排行榜"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSection
                    font.bold: true
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            CuteButton {
                tone: "primary"
                text: "＋ 新建小组"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mainWin.dlgGroup.openDialog()
            }
        }

        // ===== 领奖台（暗场舞台 + 射灯）=====
        Rectangle {
            width: parent.width
            height: 368
            radius: Theme.radius
            color: "#f7fafc"
            border.color: "#e4ecf2"
            border.width: 1
            clip: true
            visible: reward.groups.length > 0

            // 深色舞台：铺满整个面板（幕布完整垂落不裁脚）
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height
                clip: true
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height + 40
                    radius: Theme.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#171e2b" }
                        GradientStop { position: 0.75; color: "#27344a" }
                        GradientStop { position: 1.0; color: "#2d3d56" }
                    }
                }
            }
            Podium {
                id: podium
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                topGap: 130
                width: parent.width
                g1: reward.groups.length > 0 ? reward.groups[0] : null
                g2: reward.groups.length > 1 ? reward.groups[1] : null
                g3: reward.groups.length > 2 ? reward.groups[2] : null
            }
        }

        // ===== 全部小组方块（含前三名）=====
        Text {
            text: "全部小组（右键小组可改名/删除）"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
            visible: reward.groups.length > 0
        }
        Flow {
            width: parent.width
            spacing: 12
            Repeater {
                model: reward.groups
                // 小组卡片：与学生卡片同一套 Card 设计（半透明白玻璃 + 柔和投影 + 悬停上浮）
                delegate: Card {
                    id: gCard
                    property int val: 1          // 自填分值；由下面的 PointsPill 胶囊直接改
                    width: 300
                    radius: Theme.radius
                    cardColor: "#4dffffff"
                    borderColor: "transparent"
                    shadow: true
                    liftOnHover: true

                    // 组员(学号+姓名)全量展示：卡片随组员行数自动长高，不裁剪
                    Column {
                        id: gBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // 原来只有 topMargin，左右贴边 → 文字紧挨卡片边缘。补足四周内边距
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 14
                        spacing: 6
                        Text { // 组名
                            width: parent.width
                            text: modelData.name
                            color: Theme.textPrimary
                            font.pixelSize: 20
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "总分 " + modelData.points + " 分 · 组员 " + modelData.members.length + " 人"
                            color: Theme.accentDark
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            font.family: Theme.fontFamily
                        }
                        // 组员（学号+姓名），自动换行、不裁切
                        Text {
                            visible: modelData.members.length === 0
                            width: parent.width
                            text: "暂无组员（花名册右键学生 → 移到本组）"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                        Flow {
                            visible: modelData.members.length > 0
                            width: parent.width
                            spacing: 5
                            Repeater {
                                model: modelData.members
                                delegate: Rectangle {
                                    height: 21
                                    radius: Theme.radiusPill
                                    color: "#eef3f8"
                                    border.color: "#dce4ee"
                                    border.width: 1
                                    width: memTxt.implicitWidth + 12
                                    Text {
                                        id: memTxt
                                        text: modelData.studentId + " " + modelData.name
                                        anchors.centerIn: parent
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }
                        Item { height: 2; width: 1 }
                        // 自填分值 + 加减
                        Row {
                            spacing: 8
                            // 分值微调胶囊（全站统一样式）；右边两个 RoundBtn 是"应用到本组"的动作，不是调数值
                            PointsPill {
                                id: gVal
                                from: 1
                                to: 99
                                value: gCard.val
                                anchors.verticalCenter: parent.verticalCenter
                                onEdited: gCard.val = value
                            }
                            Item { width: 2; height: 1 }
                            RoundBtn { size: 28; accent: true; scheme: "aurora"; icon: "plus"; anchors.verticalCenter: parent.verticalCenter; onClicked: reward.addGroupPoints(modelData.id, gCard.val) }
                            RoundBtn { size: 28; accent: true; scheme: "crimson"; icon: "minus"; anchors.verticalCenter: parent.verticalCenter; onClicked: reward.subtractGroupPoints(modelData.id, gCard.val) }
                        }
                    }
                    // 卡片高度随内容自动（上 14 + 内容 + 下 16，与新内边距一致）
                    height: gBody.implicitHeight + 30

                    // 右键菜单（整卡右键）
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                                mainWin.openGroupMenu(gCard, modelData.id, modelData.name)
                        }
                    }
                }
            }
        }
    }
}
