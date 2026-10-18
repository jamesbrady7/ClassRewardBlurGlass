import QtQuick

// 对话框里的「标签 + 输入框」字段
Column {
    id: root

    property string label: ""
    property alias text: input.text
    property alias input: input

    spacing: 5
    width: parent ? parent.width : 300

    Text {
        text: root.label
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSmall
        font.family: Theme.fontFamily
    }
    Rectangle {
        id: box
        width: root.width
        height: 38
        radius: Theme.radiusSmall
        // 底色：静息=半透明白玻璃，聚焦=提亮 —— 与积分商店搜索栏同一档
        // ⚠️ 静息不能再是 Theme.surface（纯白不透明）：那样"聚焦提亮"就没地方可提了，
        //    高亮必须靠静息态压暗来换取对比。
        color: input.activeFocus ? Theme.glassActive : Theme.glassIdle
        // **不要边框**：原来聚焦时画 1px 强调色硬边，在这一片浅色玻璃上会读成"框了一条线"。
        // 聚焦的提示改由下面那圈"向内渐隐的内阴影"承担（同搜索栏展开态）。
        border.width: 0
        Behavior on color { ColorAnimation { duration: 140 } }

        // ⚠️ 这里原来有一圈"向内渐隐的白边"（同搜索栏静息态）。用户看了觉得那是描边，
        //    要求"输入文字的框不要有描边" → 已去掉。静息态只剩半透明底，边界靠底色差体现。
        // 聚焦：由边缘**向内渐隐**的内阴影（内凹感），约 55% 处消失
        // 声明在 TextInput 之前 = 压在文字下面，不会糊到输入内容
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, box.radius - 1)
            visible: opacity > 0.01
            opacity: input.activeFocus ? 1 : 0
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(0.35, 0.40, 0.50, 0.15) }
                GradientStop { position: 0.55; color: Qt.rgba(0.35, 0.40, 0.50, 0.0) }
            }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: Text.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
            clip: true
        }
    }
}
