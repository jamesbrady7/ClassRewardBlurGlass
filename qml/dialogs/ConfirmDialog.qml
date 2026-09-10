import QtQuick
import "../components"

// 通用确认对话框（删除等危险操作）
Modal {
    id: root

    property string promptText: ""
    property var onConfirm: null
    property string okText: "删除"

    function openConfirm(title, text, cb, ok) {
        root.title = title
        root.promptText = text
        root.onConfirm = cb
        if (ok) root.okText = ok
        root.show()
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 16
            Text {
                text: root.promptText
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                font.family: Theme.fontFamily
            }
            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 180; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "danger"; text: root.okText; onClicked: {
                    if (root.onConfirm) root.onConfirm()
                    root.hide()
                } }
            }
        }
    }
}
