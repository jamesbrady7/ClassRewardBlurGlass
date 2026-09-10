import QtQuick

// 彩色圆形头像：显示首字，底色随小组色（对未定义输入做防御）
Rectangle {
    id: root

    property string text: ""
    property color bgColor: Theme.accent
    property real size: 30

    width: size
    height: size
    radius: size / 2
    color: root.bgColor

    Text {
        text: root.text ? root.text.charAt(0) : "?"
        anchors.centerIn: parent
        color: "#ffffff"
        font.pixelSize: Math.round(root.size * 0.42)
        font.bold: true
        font.family: Theme.fontFamily
    }
}
