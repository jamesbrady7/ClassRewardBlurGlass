import QtQuick
import QtQuick.Effects

// 真·毛玻璃面板：捕获背后内容 → 高斯模糊 → 叠加半透明白色 tint
// source = 背景层（要被模糊的内容）；放在背景层之上、与其同父级。
Item {
    id: root

    property Item source: null
    property color tint: "#ccffffff"
    property real blur: 1.0
    property real radius: Theme.radius

    function updateRect() {
        if (root.source) {
            var pos = root.mapToItem(root.source, 0, 0)
            fx.sourceRect = Qt.rect(pos.x, pos.y, root.width, root.height)
        }
    }
    onXChanged: updateRect()
    onYChanged: updateRect()
    onWidthChanged: updateRect()
    onHeightChanged: updateRect()
    Component.onCompleted: updateRect()

    ShaderEffectSource {
        id: fx
        anchors.fill: parent
        sourceItem: root.source
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: fx
        blurEnabled: true
        blur: root.blur
    }
    Rectangle {
        anchors.fill: parent
        color: root.tint
        radius: root.radius
    }
}
