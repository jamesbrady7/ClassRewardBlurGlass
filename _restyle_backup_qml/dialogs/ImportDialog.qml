import QtQuick
import "../components"

// 批量导入学生：粘贴 CSV + 选择目标小组
Modal {
    id: root

    title: "批量导入学生"
    property string selectedGid: ""
    function openDialog() { root.selectedGid = ""; root.show() }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 12

            Text {
                text: "每行一个，格式：学号,姓名"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            Rectangle {
                width: parent.width
                height: 130
                radius: Theme.radiusSmall
                color: Theme.bgTop
                border.color: edit.activeFocus ? Theme.accent : Theme.inputBorder
                border.width: 1
                TextEdit {
                    id: edit
                    anchors.fill: parent
                    anchors.margins: 10
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                }
            }
            Text {
                text: "目标小组"
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
                Item { width: parent.width - 190; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "primary"; text: "开始导入"; onClicked: {
                    mainWin.toast.show(reward.importStudents(edit.text, root.selectedGid))
                    root.hide()
                } }
            }
        }
    }
}
