import QtQuick
import "../components"

// 秒表工具（工具箱里的一项）：分段计时，每按一次「计次」记一组用时。
// 状态全部在共享 TimerHub。
Item {
    id: root
    property QtObject hub: null

    Item {
        id: top
        width: parent.width
        height: 200

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            text: root.hub ? root.hub.fmtSw(root.hub.swElapsed) : "00:00.00"
            color: Theme.textPrimary
            font.pixelSize: 68
            font.bold: true
            font.family: Theme.fontFamily
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            height: 48
            spacing: 10

            CuteButton {
                tone: "primary"
                text: !root.hub ? "开始"
                      : root.hub.swRunning ? "暂停"
                      : (root.hub.swElapsed > 0 ? "继续" : "开始")
                implicitWidth: 122; implicitHeight: 48; fontSize: 17
                onClicked: if (root.hub) root.hub.swToggle()
            }
            CuteButton {
                tone: "secondary"
                text: "计次"
                implicitWidth: 100; implicitHeight: 48; fontSize: 17
                usable: root.hub && (root.hub.swRunning || root.hub.swElapsed > 0)
                onClicked: if (root.hub) root.hub.swLap()
            }
            CuteButton {
                tone: "secondary"
                text: "重置"
                implicitWidth: 90; implicitHeight: 48; fontSize: 17
                onClicked: if (root.hub) root.hub.swReset()
            }
        }
    }

    // 分段列表：编号 / 本组用时 / 累计（新记录自动滚到底部）
    ListView {
        id: splitList
        anchors.top: top.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.hub ? root.hub.swSplits : []
        onCountChanged: positionViewAtEnd()

        delegate: Rectangle {
            required property int index
            required property var modelData

            width: splitList.width
            height: 40
            radius: 11
            color: Theme.fillGlass

            Rectangle {
                id: numBadge
                width: 24; height: 24; radius: 12
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accentSoft
                Text {
                    anchors.centerIn: parent
                    text: index + 1
                    color: Theme.accent
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }
            Text {
                anchors.left: numBadge.right; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.hub ? root.hub.fmtSw(modelData.seg) : ""
                color: Theme.textPrimary
                font.pixelSize: 16
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.hub ? "累计 " + root.hub.fmtSw(modelData.total) : ""
                color: Theme.textMuted
                font.pixelSize: 12
                font.family: Theme.fontFamily
            }
        }
    }
}
