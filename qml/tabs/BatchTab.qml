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

    // 学生方块区：**照搬原型的平铺规则** —— Grid 固定 10 列、方块正方形 42px、间距 18、整块居中
    // （原型 rows=5 / cols=10 / chipSize=42 / chipGap=18，正好 5 行 × 10 列 = 50 个）
    Card {
        id: badgeCard
        width: parent.width
        height: grid.height + 28          // 高度随行数自适应（满班 5 行时 ≈ 282 + 28）
        radius: Theme.radius
        cardColor: "#4dffffff"
        Flickable {
            id: badges
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: width
            contentHeight: grid.height
            clip: true
            Grid {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter   // 整块居中（同原型）
                columns: 10                                          // 固定 10 列（同原型）
                spacing: 18                                          // chipGap（同原型）
                Repeater {
                    model: reward.students
                    delegate: StudentChip {
                        id: badge
                        width: 42; height: 42                        // 正方形（同原型 chipSize）
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
                // ⚠️ 原来是 soft/secondary 两档 —— CuteButton 重写后两者都渲染成半透明玻璃，
                //    选中根本看不出来。改用"选中=彩色实底(primary 的杂糅渐变) / 未选=玻璃"，
                //    点击后一眼可辨（加减分前必须先选分类，这个高亮是操作前提）
                tone: root.cat === modelData ? "primary" : "secondary"
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
