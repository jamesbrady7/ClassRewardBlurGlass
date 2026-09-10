import QtQuick
import QtQuick.Effects

// iOS 质感玻璃卡：垂直渐变白玻璃 + 顶 1px 内高光 + 底淡暗缘（受光公式）
// cardColor 不指定 → 默认渐变玻璃；指定 → 纯色板（可半透明）
Rectangle {
    id: root

    property color cardColor: "transparent"
    property color borderColor: "#73ffffff"
    property bool shadow: false

    radius: Theme.radius
    color: "transparent"
    border.color: root.borderColor
    border.width: 1

    // 底：玻璃体（默认=上亮下透的垂直渐变）
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.cardColor.a > 0.01
        color: root.cardColor
    }
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.cardColor.a <= 0.01
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#b5ffffff" }
            GradientStop { position: 1.0; color: "#52ffffff" }
        }
    }
    // 顶缘内高光（玻璃受光的灵魂）
    Rectangle {
        anchors.top: parent.top; anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 20
        height: 1
        radius: 1
        color: "#a3ffffff"
    }
    // 底缘暗线（厚度感）
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        height: 1
        radius: 1
        color: "#0f000000"
    }

    layer.enabled: root.shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#1a1f2937"
        shadowBlur: 0.5
        shadowVerticalOffset: 3
    }
}
