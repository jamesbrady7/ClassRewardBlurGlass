import QtQuick
import QtQuick.Effects

// 主题化按钮：primary(翡翠主操作) / secondary(白底细边) / danger(红) / soft(浅绿)
Rectangle {
    id: root

    property string tone: "secondary"
    property string text: ""
    property real fontSize: Theme.fontBody
    property bool usable: true
    signal clicked()

    implicitWidth: txt.implicitWidth + 40
    implicitHeight: 38

    function baseColor() {
        // 全部走半透玻璃色，压在彩色壁纸上
        return tone === "primary" ? Qt.alpha(Theme.accent, 0.86)
             : tone === "pink" ? Qt.alpha(Theme.pink, 0.86)
             : tone === "blue" ? Qt.alpha(Theme.blue, 0.86)
             : tone === "danger" ? Qt.alpha(Theme.red, 0.88)
             : tone === "soft" ? Qt.alpha(Theme.accentSoft, 0.72)
             : "#b0ffffff"
    }
    function hoverColor() {
        return tone === "primary" ? Qt.darker(Theme.accent, 1.1)
             : tone === "pink" ? Qt.lighter(Theme.pink, 1.08)
             : tone === "blue" ? Qt.lighter(Theme.blue, 1.08)
             : tone === "danger" ? Qt.lighter(Theme.red, 1.1)
             : tone === "soft" ? Qt.lighter(Theme.accentSoft, 1.03)
             : Theme.bgTop
    }
    function pressedColor() {
        return tone === "primary" ? Theme.accentDark
             : tone === "pink" ? Qt.darker(Theme.pink, 1.1)
             : tone === "blue" ? Qt.darker(Theme.blue, 1.1)
             : tone === "danger" ? Qt.darker(Theme.red, 1.1)
             : tone === "soft" ? Qt.darker(Theme.accentSoft, 1.05)
             : "#e6ecf3"
    }
    function borderColor() {
        return tone === "secondary" ? Theme.inputBorder
             : tone === "soft" ? "#c9d9e8"
             : "transparent"
    }
    function fgColor() {
        return (tone === "primary" || tone === "pink" || tone === "blue" || tone === "danger") ? "#ffffff"
             : tone === "soft" ? Theme.accentDark
             : Theme.textPrimary
    }

    radius: Theme.radiusSmall
    color: !root.usable ? "#eef1f5"
         : mouse.pressed ? root.pressedColor()
         : mouse.containsMouse ? root.hoverColor()
         : root.baseColor()
    border.color: !root.usable ? Theme.border
                : mouse.containsMouse ? Theme.accent
                : root.borderColor()
    border.width: 1
    opacity: root.usable ? 1 : 0.6
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: txt
        text: root.text
        anchors.centerIn: parent
        color: root.fgColor()
        font.pixelSize: root.fontSize
        font.bold: true
        font.family: Theme.fontFamily
        opacity: root.usable ? 1 : 0.7
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.usable) root.clicked()
    }
}
