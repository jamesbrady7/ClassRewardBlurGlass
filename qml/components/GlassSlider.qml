import QtQuick

// 玻璃滑块：渐变进度 + 白球旋钮，可拖拽（照搬原型 GlassSlider.qml）
//   · value 是**归一化**的 0..1，具体量程由调用方自己映射
//   · 本应用无昼夜模式 → 只把轨道槽色 theme.groove 补进 Theme，其余原型就是写死的色值
Item {
    id: root
    property real value: 0.5   // 0..1
    implicitWidth: 240
    implicitHeight: 30

    onValueChanged: value = Math.min(1, Math.max(0, value))

    // 轨道槽
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 6
        radius: 3
        color: Theme.groove
    }

    // 已走过的进度（薄荷 → 蓝紫渐变）
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 1
        height: 4
        radius: 2
        width: Math.max(4, (root.width - 2) * root.value)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#7fd8b8" }
            GradientStop { position: 1.0; color: "#7f9ef2" }
        }
    }

    // 白球旋钮
    Rectangle {
        id: knob
        x: root.value * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20
        radius: 10
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.95)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffffff" }
            GradientStop { position: 1.0; color: "#e9edf5" }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6        // 加大可点区域，细轨也拖得动
        cursorShape: Qt.PointingHandCursor
        function apply(mouse) {
            root.value = Math.min(1, Math.max(0, mouse.x / root.width))
        }
        onPositionChanged: (mouse) => apply(mouse)
        onPressed: (mouse) => apply(mouse)
        onClicked: (mouse) => apply(mouse)
    }
}
