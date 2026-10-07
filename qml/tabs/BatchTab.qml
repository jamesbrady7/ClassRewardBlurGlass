import QtQuick
import "../components"

// 批量操作：勾选学生徽章，一次性加减分
Column {
    id: root

    property string sel: ""          // 逗号分隔的学生 id
    property string cat: ""
    readonly property int total: reward.students.length
    readonly property int checkedCount: root.sel ? root.sel.split(',').length : 0
    // 分值量程（滑条映射到 1..pointsMax）。要改量程只动这一个数。
    readonly property int pointsMax: 10
    property int points: 1           // 当前分值
    function contains(id) { return root.sel.split(',').indexOf(id) >= 0 }
    function setAll(on) {
        root.sel = on ? reward.students.map(function(s) { return s.id }).join(',') : ""
    }
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
                    // **固定 50 格 = 5 行 × 10 列**（同原型）：前 N 格是学生，多出来的留空占位
                    model: 50
                    delegate: Item {
                        width: 42; height: 42                        // 正方形（同原型 chipSize）
                        readonly property var stu: index < reward.students.length
                                                   ? reward.students[index] : null
                        StudentChip {
                            anchors.fill: parent
                            visible: parent.stu !== null
                            // 学号 + 姓名直接显示在方块上（导入名单后即刻可见）
                            idText: parent.stu ? parent.stu.studentId : ""
                            label: parent.stu ? (parent.stu.name.length > 3
                                                 ? parent.stu.name.slice(0, 3) : parent.stu.name) : ""
                            selected: parent.stu ? root.contains(parent.stu.id) : false
                            onToggled: if (parent.stu) root.toggle(parent.stu.id)
                        }
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
            // 「全选」标签 + 玻璃开关（照原型 StudentsPage：标签在左、开关在右，两个按钮合成一个开关）
            Text {
                text: "全选"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textMuted
                font.pixelSize: 12
                font.family: Theme.fontFamily
            }
            GlassSwitch {
                id: allSwitch
                objectName: "allSwitch"          // 便于自动化测试取真实几何
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    root.setAll(checked)
                    mainWin.toast.show(checked ? ("已全选 " + root.total + " 人") : "已取消全选")
                }
            }
            // ⚠️ 不能用 `checked: ...` 绑定：GlassSwitch 点击时会自己写 checked，
            //    第一次点击就把绑定打断，之后开关不再反映真实选中状态。
            //    用 Connections 单向同步（程序化改 checked 不会触发 toggled，不会和点击打架）。
            Connections {
                target: root
                function onCheckedCountChanged() {
                    allSwitch.checked = root.total > 0 && root.checkedCount === root.total
                }
            }
            Item { width: 6; height: 1 }
            Text { text: "分值"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
            // **一个胶囊装下数值 + 加减**：靠左大面积是数值，靠右是一上一下两个 + / −。
            // 加减区**不画按钮底、也不描边** —— 平时就是两个符号，只有悬停时才浮一层淡白底提示可点。
            // （不用滑条、也不用原来那两个大圆按钮）
            Rectangle {
                id: pointsPill
                objectName: "pointsPill"        // 便于自动化测试取真实几何
                width: 64
                height: 34
                radius: height / 2
                // 底色：与「操作分类」未选中按钮同款（CuteButton 次级态的 fillGlass #80ffffff，
                // 悬停时它用 #bdffffff）—— 全站"玻璃面"就是这一个色，别自己另起一个灰蓝
                color: "#80ffffff"
                anchors.verticalCenter: parent.verticalCenter

                // 左：数值，占大部分宽度（自动撑到加减区左边）
                Text {
                    anchors.left: parent.left
                    anchors.right: spinCol.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: String(root.points)
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
                            width: 22; height: 16
                            // 悬停提示：淡白圆角底（不是边框，平时完全透明）
                            // 胶囊本身就是 50% 白，悬停要更亮一点才看得出来
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
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
                                onClicked: root.points = Math.max(1, Math.min(root.pointsMax,
                                                                              root.points + modelData))
                            }
                        }
                    }
                }
            }
            Item { width: 12; height: 1 }
            // 应用：按上面的分值给所选学生加 / 扣
            CuteButton { tone: "primary"; text: "加分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.op(true) }
            CuteButton { tone: "danger"; text: "扣分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.op(false) }
            Item { width: 6; height: 1 }
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
                // 再次点击同一个分类 = 取消选中（op() 会提示"请先选择操作分类标签"）
                onClicked: root.cat = (root.cat === modelData ? "" : modelData)
            }
        }
    }

    function op(isAdd) {
        if (!root.sel) { mainWin.toast.show("请先点选要操作的学生", 2000, true); return }
        if (!root.cat) { mainWin.toast.show("请先选择操作分类标签，再进行" + (isAdd ? "加分" : "扣分"), 2000, true); return }
        mainWin.toast.show(reward.batchPointChange(root.sel, root.points, isAdd, root.cat))
        root.sel = ""
    }
}
