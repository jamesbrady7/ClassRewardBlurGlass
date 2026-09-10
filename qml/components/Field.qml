import QtQuick

// 对话框里的「标签 + 输入框」字段
Column {
    id: root

    property string label: ""
    property alias text: input.text
    property alias input: input

    spacing: 5
    width: parent ? parent.width : 300

    Text {
        text: root.label
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily
    }
    Rectangle {
        width: root.width
        height: 38
        radius: Theme.radiusSmall
        color: Theme.surface
        border.color: input.activeFocus ? Theme.accent : Theme.inputBorder
        border.width: 1
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: Text.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
            clip: true
        }
    }
}
