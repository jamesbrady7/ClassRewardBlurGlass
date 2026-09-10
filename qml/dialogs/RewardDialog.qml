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
            Row {
                spacing: 6
                Repeater {
                    model: ["普通", "稀有", "史诗", "传说"]
                    delegate: CuteButton {
                        tone: root.cat === modelData ? "soft" : "secondary"
                        text: modelData
                        onClicked: root.cat = modelData
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
