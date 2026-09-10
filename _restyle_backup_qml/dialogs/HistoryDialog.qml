import QtQuick
import "../components"

// 单个学生的积分历史：固定列宽、逐行锚点、每列水平居中、可滚动；撤回也入历史
Modal {
    id: root

    title: "学生历史"
    function openDialog(sid) {
        reward.openHistory(sid)
        root.show()
    }

    readonly property real colT: 104
    readonly property real colK: 76
    readonly property real colP: 60

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 6

            // 表头（全部居中对齐）
            Item {
                width: parent.width
                height: 22
                visible: reward.historyItems.length > 0
                Text { width: root.colT; height: parent.height; anchors.left: parent.left; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "时间"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                Text { width: root.colK; height: parent.height; anchors.left: parent.left; anchors.leftMargin: root.colT; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "类型"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                Text { width: root.colP; height: parent.height; anchors.left: parent.left; anchors.leftMargin: root.colT + root.colK; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "分值"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                Text { anchors.left: parent.left; anchors.leftMargin: root.colT + root.colK + root.colP; anchors.right: parent.right; height: parent.height; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "说明"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
            }

            Flickable {
                width: parent.width
                height: Math.min(360, Math.max(0, reward.historyItems.length * 34 + 2))
                clip: true
                visible: reward.historyItems.length > 0
                contentHeight: rows.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: rows
                    width: parent.width
                    Repeater {
                        model: reward.historyItems
                        delegate: Item {
                            width: parent.width
                            height: 34
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#edf1f6"
                                anchors.bottom: parent.bottom
                            }
                            Text { // 时间（居中）
                                width: root.colT
                                height: parent.height
                                anchors.left: parent.left
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.time
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                            Rectangle { // 类型（药丸在列内居中）
                                width: root.colK
                                height: 24
                                radius: Theme.radiusPill
                                anchors.left: parent.left
                                anchors.leftMargin: root.colT
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData.typeLabel === "加分" ? Theme.greenSoft
                                     : modelData.typeLabel === "扣分" ? Theme.redSoft
                                     : modelData.typeLabel === "撤回" ? Theme.purpleSoft
                                     : Theme.blueSoft
                                Text {
                                    text: modelData.typeLabel
                                    anchors.centerIn: parent
                                    color: modelData.typeLabel === "加分" ? Theme.green
                                         : modelData.typeLabel === "扣分" ? Theme.red
                                         : modelData.typeLabel === "撤回" ? Theme.purple
                                         : Theme.blue
                                    font.pixelSize: Theme.fontSmall
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                }
                            }
                            Text { // 分值（居中）
                                width: root.colP
                                height: parent.height
                                anchors.left: parent.left
                                anchors.leftMargin: root.colT + root.colK
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.points ? (modelData.points > 0 ? "+" + modelData.points : String(modelData.points)) + "分" : "—"
                                color: modelData.points > 0 ? Theme.green
                                     : modelData.points < 0 ? Theme.red
                                     : Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                font.bold: modelData.points !== 0
                                font.family: Theme.fontFamily
                            }
                            Text { // 说明（居中）
                                anchors.left: parent.left
                                anchors.leftMargin: root.colT + root.colK + root.colP
                                anchors.right: parent.right
                                height: parent.height
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.desc
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSmall
                                font.family: Theme.fontFamily
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }
            Text {
                text: "暂无记录"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textMuted
                font.pixelSize: Theme.fontBody
                font.family: Theme.fontFamily
                visible: !reward.historyItems.length
            }
        }
    }
}
