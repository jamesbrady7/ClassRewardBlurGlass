import QtQuick
import "../components"

// 每日历史：按日期分组展示所有积分变动
Column {
    id: root

    spacing: Theme.spacing

    Row {
        width: parent.width
        spacing: 10
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "每日历史"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    ListView {
        id: histList
        width: parent.width
        height: parent.height - 40
        clip: true
        spacing: 10
        model: reward.history

        delegate: Column {
            width: histList.width
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
                radius: Theme.radius
                Column {
                    width: parent.width
                    anchors.margins: 6
                    spacing: 2
                    Repeater {
                        model: modelData.entries
                        delegate: Row {
                            width: parent.width
                            height: 30
                            spacing: 8
                            Text {
                                width: 70
                                text: modelData.time
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                font.family: Theme.fontFamily
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: 90
                                text: modelData.name + "(" + modelData.studentId + ")"
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
                                width: parent.width - 250
                                text: (modelData.points ? (modelData.points > 0 ? "+" + modelData.points : modelData.points) + " 分 " : "") + modelData.desc
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
}
