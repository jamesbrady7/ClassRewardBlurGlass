import QtQuick
import "../components"

// 新增奖励
Modal {
    id: root

    title: "新增奖励"
    property string cat: "普通"
    function openDialog() { root.cat = "普通"; root.show() }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 12
            Field { id: nameField; label: "奖励名称" }
            Row {
                spacing: 14
                Text {
                    text: "所需积分"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Stepper { id: costStepper; value: 5; max: 999 }
            }
            // 分类标签：**每个分类用自己的颜色**（普通蓝/稀有紫/史诗琥珀/传说红）
            // 原来用 CuteButton 的 soft/secondary 两档玻璃色 —— 四个标签长得一样，看不出谁是谁。
            // CuteButton 的 tone 只能映射固定几套 scheme，给不了任意色，所以这里自绘。
            // 选中=实色底+白字，未选=同色系浅底+分类色字（沿用商店奖励券的配色语言）。
            Row {
                spacing: 6
                Repeater {
                    model: ["普通", "稀有", "史诗", "传说"]
                    delegate: Rectangle {
                        readonly property bool on: root.cat === modelData
                        width: catLabel.implicitWidth + 28
                        height: 32
                        radius: Theme.radiusPill
                        color: on ? Theme.catFg(modelData) : Theme.catSoft(modelData)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            id: catLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: on ? "#ffffff" : Theme.catFg(modelData)
                            font.pixelSize: Theme.fontSmall
                            font.bold: on
                            font.family: Theme.fontFamily
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cat = modelData
                        }
                    }
                }
            }
            Field { id: descField; label: "奖励描述（可选）" }
            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 180; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "primary"; text: "保存"; onClicked: {
                    if (nameField.text.trim())
                        reward.addReward(nameField.text.trim(), costStepper.value, root.cat, descField.text.trim())
                    root.hide()
                } }
            }
        }
    }
}
