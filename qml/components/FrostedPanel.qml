import QtQuick
import QtQuick.Effects

// 真·毛玻璃面板：捕获背后内容 → 高斯模糊 → 圆角遮罩 → 叠加半透明白色 tint
// source = 背景层（要被模糊的内容）；放在背景层之上、与其同父级。
Item {
    id: root

    property Item source: null
    property color tint: "#ccffffff"
    property real blur: 1.0
    property real radius: Theme.radius
    // 柔和投影（默认关，避免影响既有调用方）。开启后由自包含的 SoftShadow 绘制：
    // 径向渐变、边缘真正模糊，不会像硬边矩形阴影那样四周均匀外扩成"描边环"
    property bool shadow: false
    property color shadowColor: "#38202830"

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

    // 投影（最底层；面板本体盖在它上面）
    SoftShadow {
        visible: root.shadow
        anchors.fill: parent
        anchors.margins: -18
        anchors.topMargin: -6
        anchors.bottomMargin: -12
        softColor: root.shadowColor
    }

    ShaderEffectSource {
        id: fx
        anchors.fill: parent
        sourceItem: root.source
        visible: false
    }

    // 圆角遮罩：把**方形的模糊**裁成圆角。
    // ⚠️ 原来缺这一步——圆角只是盖在模糊上面那层 tint 的形状，
    //    模糊本身仍是方的，圆角之外会漏出模糊的方角。
    Item {
        id: maskShape
        visible: false
        width: Math.max(2, root.width)
        height: Math.max(2, root.height)
        Rectangle { anchors.fill: parent; radius: root.radius; color: "white" }
    }
    ShaderEffectSource {
        id: maskTex
        visible: false
        sourceItem: maskShape
        live: true
        textureSize: fx.textureSize
    }

    MultiEffect {
        anchors.fill: parent
        source: fx
        // ⚠️ 必须 false：padding 自动扩展会把 maskSource 映射错位 → 模糊输出半透明、下层透出
        autoPaddingEnabled: false
        blurEnabled: true
        blur: root.blur
        maskEnabled: true
        maskSource: maskTex
        maskThresholdMin: 0.1
        maskThresholdMax: 0.6
    }
    Rectangle {
        anchors.fill: parent
        color: root.tint
        radius: root.radius
    }
}
