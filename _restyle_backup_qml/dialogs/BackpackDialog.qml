import QtQuick
import "../components"

// 学生奖励背包：查看 + 使用
Modal {
    id: root

    title: "奖励背包"
    property string studentId: ""
    function openDialog(sid) {
        root.studentId = sid
        reward.openBackpack(sid)
        root.show()
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: reward.backpackItems
                delegate: Row {
                    width: parent.width
                    height: 40
                    spacing: 10
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: modelData.isBlind ? Theme.amberSoft : Theme.accentSoft
                        Text {
                            text: modelData.isBlind ? "🎁" : "🎫"
                            anchors.centerIn: parent
                            font.pixelSize: 16
                        }
                    }
                    Column {
                        width: parent.width - 130
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: modelData.name
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: "获得于 " + modelData.time
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                        }
                    }
                    CuteButton {
                        tone: "soft"
                        text: "使用"
                        implicitWidth: 70
                        implicitHeight: 32
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: mainWin.toast.show(reward.useItem(root.studentId, modelData.id))
                    }
                }
            }

            Text {
                text: reward.backpackItems.length ? "" : "背包是空的，快去积分商店兑换奖品吧！"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textMuted
                font.pixelSize: Theme.fontBody
                font.family: Theme.fontFamily
                visible: !reward.backpackItems.length
            }
        }
    }
}
