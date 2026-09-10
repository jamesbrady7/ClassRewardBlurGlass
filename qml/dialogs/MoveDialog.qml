import QtQuick
import "../components"

// 移动学生到另一个小组
Modal {
    id: root

    title: "移动学生"
    property string studentId: ""
    property string selectedGid: ""
    function openDialog(sid) {
        root.studentId = sid
        root.selectedGid = ""
        root.show()
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 14
            Text {
                text: "选择目标小组："
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            Row {
                width: parent.width
                spacing: 6
                CuteButton {
                    tone: root.selectedGid === "" ? "soft" : "secondary"
                    text: "无小组"
                    onClicked: root.selectedGid = ""
                }
                Repeater {
                    model: reward.groups
                    delegate: CuteButton {
                        tone: root.selectedGid === modelData.id ? "soft" : "secondary"
                        text: modelData.name
                        onClicked: root.selectedGid = modelData.id
                    }
                }
            }
            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 180; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "primary"; text: "移动"; onClicked: {
                    reward.moveStudent(root.studentId, root.selectedGid)
                    root.hide()
                } }
            }
        }
    }
}
