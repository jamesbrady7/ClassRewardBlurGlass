import QtQuick

// 数字步进器：替代原生 QSpinBox（− 值 ＋）
Row {
    id: root

    property int value: 1
    property int min: 1
    property int max: 999
    property int step: 1
    property int heightSize: 32
    signal changed()

    spacing: 2

    CuteButton {
        text: "−"
        implicitWidth: 30
        implicitHeight: root.heightSize
        onClicked: { root.value = Math.max(root.min, root.value - root.step); root.changed() }
    }
    Rectangle {
        width: 46
        height: root.heightSize
        radius: Theme.radiusSmall
        color: Theme.surface
        border.color: Theme.inputBorder
        border.width: 1
        Text {
            text: root.value
            anchors.centerIn: parent
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
        }
    }
    CuteButton {
        text: "＋"
        implicitWidth: 30
        implicitHeight: root.heightSize
        onClicked: { root.value = Math.min(root.max, root.value + root.step); root.changed() }
    }
}
