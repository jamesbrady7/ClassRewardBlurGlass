import QtQuick

// 圆角药丸标签：学号牌 / 小组标签 / 分数牌等
Rectangle {
    id: root

    property string text: ""
    property color bg: Theme.accentSoft
    property color fg: Theme.accentDark
    property color borderColor: "transparent"
    property real fontSize: Theme.fontSmall
    property bool bold: false

    radius: Theme.radiusPill
    color: bg
    border.color: root.borderColor
    border.width: root.borderColor === "transparent" ? 0 : 1
    implicitHeight: txt.implicitHeight + 8
    implicitWidth: txt.implicitWidth + 18

    Text {
        id: txt
        text: root.text
        anchors.centerIn: parent
        color: root.fg
        font.pixelSize: root.fontSize
        font.bold: root.bold
        font.family: Theme.fontFamily
    }
}
