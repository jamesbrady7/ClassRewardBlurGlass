import QtQuick
import "../components"

// 新建小组：名称 + 选择初始成员（未分组学生）
Modal {
    id: root

    title: "新建小组"
    property string sel: ""          // 逗号分隔的成员 id（字符串变更会触发绑定重算）
    function openDialog() { root.sel = ""; root.show() }
    function contains(id) { return root.sel.split(',').indexOf(id) >= 0 }
    function toggle(id) {
        var arr = root.sel ? root.sel.split(',') : []
        var idx = arr.indexOf(id)
        if (idx >= 0) arr.splice(idx, 1); else arr.push(id)
        root.sel = arr.join(',')
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 12
            Field { id: nameField; label: "小组名称" }
            Text {
                text: "选择初始成员（可选）"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: {
                        var arr = []
                        for (var i = 0; i < reward.students.length; i++)
                            if (!reward.students[i].groupId) arr.push(reward.students[i])
                        return arr
                    }
                    delegate: Rectangle {
                        width: 98
                        height: 34
                        radius: Theme.radiusPill
                        color: root.contains(modelData.id) ? Theme.accentSoft : Theme.bgTop
                        border.color: root.contains(modelData.id) ? Theme.accent : "transparent"
                        border.width: 1
                        Text {
                            text: modelData.studentId + " " + modelData.name
                            anchors.centerIn: parent
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(modelData.id)
                        }
                    }
                }
            }
            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 180; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton { tone: "primary"; text: "创建"; onClicked: {
                    if (nameField.text.trim())
                        reward.addGroup(nameField.text.trim(), root.sel)
                    root.hide()
                } }
            }
        }
    }
}
