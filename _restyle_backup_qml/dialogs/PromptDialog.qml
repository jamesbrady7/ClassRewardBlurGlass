import QtQuick
import "../components"

// 通用文本输入对话框（新班级 / 重命名小组等）
Modal {
    id: root

    property string promptLabel: ""
    property var onAccept: null

    function openPrompt(title, label, cb) {
        root.title = title
        root.promptLabel = label
        root.onAccept = cb
        root.show()
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 16
            Field { id: input; label: root.promptLabel; text: "" }
            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 180; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "primary"; text: "确定"; onClicked: {
                    if (root.onAccept) root.onAccept(input.text.trim())
                    root.hide()
                } }
            }
        }
    }
}
