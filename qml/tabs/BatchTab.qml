import QtQuick
import "../components"

// 批量操作：勾选学生徽章，一次性加减分
Column {
    id: root

    property string sel: ""          // 逗号分隔的学生 id
    property string cat: ""
    function contains(id) { return root.sel.split(',').indexOf(id) >= 0 }
    function toggle(id) {
        var arr = root.sel ? root.sel.split(',') : []
        var idx = arr.indexOf(id)
        if (idx >= 0) arr.splice(idx, 1); else arr.push(id)
        root.sel = arr.join(',')
    }

    spacing: Theme.spacing

    Row {
        width: parent.width
        spacing: 10
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "批量操作"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 1; height: 1 }
    }

    // 学生徽章网格（带淡色底）
    Card {
        width: parent.width
        height: 170
        radius: Theme.radius
        cardColor: "#4dffffff"
        Flickable {
            id: badges
            anchors.fill: parent
            anchors.margins: 10
            // ⚠️ 原来是 contentWidth: grid.implicitWidth + Flow.width: parent.width → **自我引用**：
            //    parent 就是 Flickable 的 contentItem，而它的宽度=contentWidth=grid.implicitWidth
            //    → Flow 的宽度被算成"一格宽"，方块全被挤成一列。改为用 Flickable 自身宽度。
            contentWidth: width
            contentHeight: grid.height
            clip: true
            Flow {
                id: grid
                width: badges.width
                spacing: 6
                Repeater {
                    model: reward.students
                    // 平铺的学生方块：照搬原型的 StudentChip（圆角方形玻璃面 + 选中彩色高亮 + 薄荷绿勾）
                    delegate: StudentChip {
                        id: badge
                        width: 56; height: 48
                        idText: modelData.studentId
                        label: modelData.name.length > 3 ? modelData.name.slice(0, 3) : modelData.name
                        selected: root.contains(modelData.id)
                        onToggled: root.toggle(modelData.id)
                    }
                }
            }
        }
    }

    // 控制栏（带淡蓝底色 + 彩色按钮区分）
    Card {
        width: parent.width
        height: 56
        radius: Theme.radius
        cardColor: "#4dffffff"
        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            CuteButton { tone: "blue"; text: "全选"; anchors.verticalCenter: parent.verticalCenter; onClicked: { root.sel = reward.students.map(function(s) { return s.id }).join(',') } }
            CuteButton { text: "取消全选"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.sel = "" }
            Item { width: 4; height: 1 }
            Text { text: "分值"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
            Stepper { id: points; value: 1; max: 999; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 4; height: 1 }
            RoundBtn { size: 34; accent: true; scheme: "aurora"; icon: "plus"; hint: "按分值给所选学生加分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.op(true) }
            RoundBtn { size: 34; accent: true; scheme: "crimson"; icon: "minus"; hint: "按分值给所选学生扣分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.op(false) }
            Item { width: 4; height: 1 }
            Pill {
                text: "已选 " + (root.sel ? root.sel.split(',').length : 0) + " 人"
                bg: Theme.accentSoft; fg: Theme.accentDark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 维度
    Row {
        width: parent.width
        spacing: 6
        Text { text: "操作分类："; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
        Repeater {
            model: reward.categories
            delegate: CuteButton {
                tone: root.cat === modelData ? "soft" : "secondary"
                text: modelData
                onClicked: root.cat = modelData
            }
        }
    }

    function op(isAdd) {
        if (!root.sel) { mainWin.toast.show("请先点选要操作的学生", 2000, true); return }
        if (!root.cat) { mainWin.toast.show("请先选择操作分类标签，再进行" + (isAdd ? "加分" : "扣分"), 2000, true); return }
        mainWin.toast.show(reward.batchPointChange(root.sel, points.value, isAdd, root.cat))
        root.sel = ""
    }
}
