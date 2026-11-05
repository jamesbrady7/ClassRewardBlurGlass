import QtQuick
import QtQuick.Controls
import "../components"

// 每日历史（两段式）：
//   ① 加扣分历史：按日期汇总「维度 + 分值 → 学号」，先加分、后扣分；
//      小组直接分单列一块，不混进学生学号。
//   ② 总览历史：全部流水（加扣分、兑换、使用道具、盲盒、撤回、小组直接分）。
// 右上角「保存今日分数截图」→ 渲染一张干净的海报存到桌面，并弹出可置顶预览窗。
Column {
    id: root

    spacing: Theme.spacing
    property int tabIndex: 0

    function saveToday() {
        var info = reward.todayScoreSaveInfo()
        if (!info || !info.hasData) {
            mainWin.toast.show("今天还没有加分或扣分记录", 2200, true)
            return
        }
        mainWin.scorePreview.openWith(info)
    }

    // ===== 标题 + 分段 tab + 保存按钮 =====
    Item {
        // 与其它页面（PageScroll 内已留 14px 滚动条空隙）保持同一右边界
        width: parent.width - 14
        height: 40

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 4; height: 20; radius: 2
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "每日历史"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSection
                font.bold: true
                font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: 2; height: 1 }
            SegmentedTabs {
                id: seg
                anchors.verticalCenter: parent.verticalCenter
                labels: ["加扣分历史", "总览历史"]
                currentIndex: root.tabIndex
                onActivated: function(idx) { root.tabIndex = idx }
            }
        }

        CuteButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            tone: "primary"
            fillScheme: "soda"          // 原型长条按钮 03（薄荷苏打）
            text: "保存今日分数截图"
            // 小一号：700px 最小窗口时，标题 + 分段 tab + 按钮刚好排得下
            fontSize: Theme.fontSmall
            onClicked: root.saveToday()
        }
    }

    // ===== 内容区 =====
    Item {
        width: parent.width
        height: parent.height - 40 - root.spacing
        clip: true

        // ── ① 加扣分历史（按日汇总）──
        ListView {
            id: ledgerList
            anchors.fill: parent
            visible: root.tabIndex === 0
            clip: true
            spacing: 10
            model: reward.ledgerHistory
            ScrollBar.vertical: ThinScrollBar {}

            delegate: Column {
                // 右侧 14px 留给滚动条：细条不会压在汇总卡上
                width: ledgerList.width - 14
                spacing: 6

                Text {
                    text: "📅 " + modelData.date
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    font.family: Theme.fontFamily
                }

                Card {
                    width: parent.width
                    height: dayBody.implicitHeight + 28
                    radius: Theme.radius
                    cardColor: Theme.cardGlass
                    shadow: true

                    Column {
                        id: dayBody
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 8

                        // ── 加分 ──
                        Row {
                            visible: modelData.hasEarn
                            spacing: 6
                            Rectangle {
                                width: 3; height: 14; radius: 1.5
                                color: Theme.green
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "加分"
                                color: Theme.green
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Repeater {
                            model: modelData.hasEarn ? modelData.earn : []
                            delegate: Row {
                                width: dayBody.width
                                height: Math.max(24, idsText.implicitHeight + 4)
                                spacing: 8
                                Text {
                                    width: 48
                                    text: modelData.category
                                    color: Theme.green
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignTop
                                }
                                Text {
                                    width: 62
                                    text: "+" + modelData.points + " 分"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignTop
                                }
                                Text {
                                    id: idsText
                                    width: parent.width - 126
                                    text: modelData.ids
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSmall
                                    font.family: Theme.fontFamily
                                    font.letterSpacing: 0.6
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignTop
                                }
                            }
                        }

                        // ── 扣分 ──
                        Row {
                            visible: modelData.hasDeduct
                            spacing: 6
                            Rectangle {
                                width: 3; height: 14; radius: 1.5
                                color: Theme.red
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "扣分"
                                color: Theme.red
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Repeater {
                            model: modelData.hasDeduct ? modelData.deduct : []
                            delegate: Row {
                                width: dayBody.width
                                height: Math.max(24, idsText.implicitHeight + 4)
                                spacing: 8
                                Text {
                                    width: 48
                                    text: modelData.category
                                    color: Theme.red
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignTop
                                }
                                Text {
                                    width: 62
                                    text: "-" + modelData.points + " 分"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignTop
                                }
                                Text {
                                    id: idsText
                                    width: parent.width - 126
                                    text: modelData.ids
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSmall
                                    font.family: Theme.fontFamily
                                    font.letterSpacing: 0.6
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignTop
                                }
                            }
                        }

                        // ── 小组直接分（不并入学生学号）──
                        Row {
                            visible: modelData.hasGroup
                            spacing: 6
                            Rectangle {
                                width: 3; height: 14; radius: 1.5
                                color: Theme.blue
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "小组直接分"
                                color: Theme.blue
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Repeater {
                            model: modelData.hasGroup ? modelData.groupEarn.concat(modelData.groupDeduct) : []
                            delegate: Row {
                                width: dayBody.width
                                height: 24
                                spacing: 8
                                Text {
                                    width: 110
                                    text: modelData.name
                                    color: Theme.blue
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    text: modelData.sign + modelData.points + " 分"
                                    color: modelData.sign === "-" ? Theme.red : Theme.textPrimary
                                    font.pixelSize: Theme.fontSmall
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── ② 总览历史（全部流水）──
        ListView {
            id: allList
            anchors.fill: parent
            visible: root.tabIndex === 1
            clip: true
            spacing: 10
            model: reward.history
            ScrollBar.vertical: ThinScrollBar {}

            delegate: Column {
                // 右侧 14px 留给滚动条：细条不会压在历史卡上
                width: allList.width - 14
                spacing: 6

                Text {
                    text: "📅 " + modelData.date
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    font.family: Theme.fontFamily
                }
                Card {
                    width: parent.width
                    height: entriesBody.implicitHeight + 20
                    radius: Theme.radius
                    cardColor: Theme.cardGlass
                    shadow: true

                    Column {
                        id: entriesBody
                        x: 10
                        y: 10
                        width: parent.width - 20
                        spacing: 2
                        Repeater {
                            model: modelData.entries
                            delegate: Row {
                                width: entriesBody.width
                                height: 30
                                spacing: 8
                                Text {
                                    width: 70
                                    height: 30
                                    text: modelData.time
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSmall
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width: 120
                                    height: 30
                                    text: modelData.isGroup
                                          ? modelData.name
                                          : (modelData.name + "(" + modelData.studentId + ")")
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSmall
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Pill {
                                    text: modelData.typeLabel
                                    bg: modelData.typeLabel === "加分" ? Theme.greenSoft
                                      : modelData.typeLabel === "扣分" ? Theme.redSoft
                                      : Theme.blueSoft
                                    fg: modelData.typeLabel === "加分" ? Theme.green
                                      : modelData.typeLabel === "扣分" ? Theme.red
                                      : Theme.blue
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: parent.width - 290
                                    height: 30
                                    text: (modelData.points
                                           ? (modelData.typeLabel === "扣分"
                                              ? "-" + modelData.points
                                              : (modelData.points > 0 ? "+" + modelData.points : modelData.points))
                                             + " 分 "
                                           : "") + modelData.desc
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSmall
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 90
            visible: root.tabIndex === 0 && ledgerList.count === 0
            text: "还没有加扣分记录"
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 90
            visible: root.tabIndex === 1 && allList.count === 0
            text: "还没有历史记录"
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
        }
    }
}
