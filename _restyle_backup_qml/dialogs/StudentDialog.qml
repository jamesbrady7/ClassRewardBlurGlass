import QtQuick
import "../components"

// 添加学生对话框
Modal {
    id: root

    title: "添加学生"
    property string presetGroupId: ""

    function openDialog(gid) {
        root.presetGroupId = gid || ""
        root.show()
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 14
            Field { id: nameField; label: "姓名" }
            Field { id: sidField; label: "学号（01-50）" }
            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 180; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "primary"; text: "保存"; onClicked: {
                    if (reward.addStudent(sidField.text.trim(), nameField.text.trim(), root.presetGroupId)) root.hide()
                    else mainWin.toast.show("添加失败：学号重复或人数已满")
                } }
            }
        }
    }
}
