import QtQuick

// 主题化按钮：**照搬原型的 GlassButton 逻辑**
//   主级(filled) = 多色杂糅弥散渐变（IridescentFill）；次级 = 半透明白玻璃
//   悬停：面增亮 + 投影加深；按压：整体缩到 0.97；零描边；投影为径向柔光晕
// tone 保持原语义，映射到原型的配色方案：primary→mint / pink→orchid / blue→marine / danger→scarlet
Item {
    id: root

    property string tone: "secondary"
    property string text: ""
    property real fontSize: Theme.fontBody
    property bool usable: true
    signal clicked()

    implicitWidth: txt.implicitWidth + 40
    implicitHeight: 38

    // tone → 原型的 scheme（未列出的 tone 走默认 mint）
    readonly property string scheme: tone === "pink" ? "orchid"
                                    : tone === "blue" ? "marine"
                                    : tone === "danger" ? "scarlet"
                                    : "mint"
    // 有彩色底 = 主级；secondary/soft 走半透明玻璃面
    readonly property bool filled: tone !== "secondary" && tone !== "soft"

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    // 按压缩放（与原型的 0.97 一致）
    scale: (root.usable && pressed) ? 0.97 : 1.0
    opacity: root.usable ? 1 : 0.6
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

    // 径向柔光晕投影（主级偏紫调、次级偏灰调；悬停加深）
    SoftShadow {
        anchors.fill: parent
        anchors.margins: -16
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        softColor: root.filled
                   ? Qt.rgba(0.42, 0.40, 0.82, hovered ? 0.34 : 0.26)
                   : Qt.rgba(0.30, 0.33, 0.48, hovered ? 0.22 : 0.15)
    }

    // 次级：均匀半透明白（悬停增亮）——原型 fillGlass / fillGlassHover
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        opacity: root.filled ? 0 : 1
        color: hovered ? "#bdffffff" : "#80ffffff"
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // 主级：多色杂糅弥散渐变
    IridescentFill {
        id: fill
        anchors.fill: parent
        rad: height / 2
        scheme: root.scheme
        opacity: root.filled ? 1 : 0
        hovered: root.hovered
        pressed: root.pressed
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Text {
        id: txt
        text: root.text
        anchors.centerIn: parent
        // 浅色面上白字对比不足 → 用深字（与原型同一条规则，由 IridescentFill.lightFace 判定）
        color: root.filled ? (fill.lightFace ? "#3f4660" : "#ffffff") : Theme.textPrimary
        font.pixelSize: root.fontSize
        font.weight: Font.DemiBold
        font.family: Theme.fontFamily
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.usable) root.clicked()
    }
}
