import QtQuick

// 分值微调胶囊：**左边大面积是数值，右边一上一下两个 + / −**。
// 全站"调分值"统一用这个（批量操作页先定的样式，抽出来共用）。
//
// 用法：PointsPill { value: 3; from: 1; to: 10; onEdited: ... }
//   value 是**可读可写**的当前分值；用户点 +/- 时组件自己改 value 并发出 edited()
//
// ⚠️ 两个几何约束（改尺寸时必看，都是踩过的坑）：
//   ① 数值的文字框是「左边距 → 加减区左边界」，**居中**显示。
//      所以数值的水平位置 = (左内边距 + 加减区左边界) / 2 ——
//      想让它更靠右，只能同时加大左内边距 + 收窄加减区，光调一个没用。
//   ② 悬停高亮底必须**内缩**：胶囊是高/2 的全圆角，右端是一整个半圆端帽；
//      高亮底若铺满 item 且用小圆角，右上/右下角会戳出端帽之外（"高亮溢出胶囊"）。
//      所以这里是 16x14 的同心小胶囊、居中内收。
Item {
    id: root

    property int value: 1
    property int from: 1
    property int to: 10
    signal edited()

    implicitWidth: 48
    implicitHeight: 34

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        // 与「操作分类」未选中按钮同款（CuteButton 次级态的 fillGlass #80ffffff）
        color: "#80ffffff"

        // 左：数值，撑到加减区左边并居中
        Text {
            anchors.left: parent.left
            anchors.right: spinCol.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: String(root.value)
            color: Theme.textPrimary
            font.pixelSize: 16
            font.bold: true
            font.family: Theme.fontFamily
        }

        // 右：一上一下两个 + / −（无边框、无固定底）
        Column {
            id: spinCol
            objectName: "pointsSpin"
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Repeater {
                model: [1, -1]          // 上=加、下=减
                delegate: Item {
                    width: 18; height: 15
                    // 悬停提示：淡白圆角底（见顶部说明②，必须内缩）
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16; height: 14
                        radius: height / 2
                        color: "#ffffff"
                        opacity: spinMa.containsMouse ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    CanvasIcon {
                        anchors.centerIn: parent
                        name: modelData > 0 ? "plus" : "minus"
                        width: 11; height: 11
                        color: Theme.textSecondary
                    }
                    MouseArea {
                        id: spinMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var nv = root.value + modelData
                            root.value = Math.max(root.from, Math.min(root.to, nv))
                            root.edited()
                        }
                    }
                }
            }
        }
    }
}
