import QtQuick
import QtQuick.Effects

// 白色圆角卡片：细边框，可选投影（投影用 MultiEffect，适合少量卡片）
Rectangle {
    id: root

    property color cardColor: Theme.surface
    property color borderColor: Theme.border
    property bool shadow: false

    radius: Theme.radius
    color: root.cardColor
    border.color: root.borderColor
    border.width: 1

    layer.enabled: root.shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#1a1f2937"
        shadowBlur: 0.5
        shadowVerticalOffset: 3
    }
}
