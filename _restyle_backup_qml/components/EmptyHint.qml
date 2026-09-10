import QtQuick

// 空状态提示
Column {
    property string text: "暂无数据"
    width: parent ? parent.width : 300
    spacing: 6

    Text { text: "🌸"; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 30 }
    Text {
        text: root.text
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.textMuted
        font.pixelSize: Theme.fontBody
        font.family: Theme.fontFamily
    }
}
