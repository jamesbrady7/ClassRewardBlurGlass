import QtQuick
import "../components"

// 小组排行榜：顶部领奖台（纯展示前三名）；下方所有小组平铺成方块。
// 每块：组员学号姓名、可自填分值后加减；右键菜单 = 更改组名 / 删除小组。
Flickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight

    // ===== 数据同步：把 bridge 的 groups 增量搬进本地 ListModel =====
    // ⚠️ 为什么不用 `model: reward.groups`：
    //    bridge 的 groups 是**每次通知都重新构造的一整个新数组**，Repeater 据此判定"模型换了"
    //    → **销毁并重建全部卡片**（实测：点一次「加分」4 张卡全部 DESTROYED + 重新 created）。
    //    表现就是卡片闪烁、卡顿，而且悬停态与自填分值一起被重置。
    //    ListModel 增量更新：加减分只走 setProperty + move()，**delegate 全程存活**（零重建）。
    ListModel { id: groupModel }

    Connections {
        target: reward
        function onDataChanged() { root.syncGroups() }
    }
    Component.onCompleted: root.syncGroups()

    // 成员牌面：「学号 姓名」用换行拼成**一个字符串**存进 role。
    // ⚠️ 数组不能放进 ListModel 的 role：**任何** JS 数组都会被转成**嵌套 ListModel**
    //    （实测 role 读出来是 QQmlListModel，连字符串数组也一样）→ 内层 Repeater 的 modelData
    //    拿不到值、还会在批量 append 时报 "Cannot read property 'members' of undefined"。
    //    所以这里存字符串，用的时候再 split。
    function memberLabels(ms) {
        var out = []
        for (var i = 0; i < (ms ? ms.length : 0); i++) out.push(ms[i].studentId + " " + ms[i].name)
        return out
    }
    function rowOf(g) {
        var labels = memberLabels(g.members)
        var s = labels.join("\n")
        return { gid: g.id, name: g.name, points: g.points,
                 mstr: s, mcount: labels.length }
    }
    function syncGroups() {
        if (!reward) return
        var gs = reward.groups
        // ① 结构变了（增删小组）→ 只能重建；其余情况一律原地更新
        var structural = (groupModel.count !== gs.length)
        if (!structural) {
            for (var i = 0; i < gs.length; i++)
                if (groupModel.get(i).gid !== gs[i].id) { structural = true; break }
        }
        if (structural) {
            groupModel.clear()
            for (var k = 0; k < gs.length; k++) groupModel.append(rowOf(gs[k]))
            return
        }
        // ② 数值 / 名字 / 成员原地更新（只刷新变化的绑定，卡片不动）
        for (var j = 0; j < gs.length; j++) {
            var g = gs[j], row = groupModel.get(j)
            if (row.points !== g.points) groupModel.setProperty(j, "points", g.points)
            if (row.name !== g.name) groupModel.setProperty(j, "name", g.name)
            var s = memberLabels(g.members).join("\n")
            if (row.mstr !== s) {
                groupModel.setProperty(j, "mstr", s)
                groupModel.setProperty(j, "mcount", s ? s.split("\n").length : 0)
            }
        }
        // ③ 名次变化用 move() 重排 —— 同样保 delegate（直接改 model 会整表重建）
        for (var t = 0; t < gs.length; t++) {
            var cur = -1
            for (var c = 0; c < groupModel.count; c++)
                if (groupModel.get(c).gid === gs[t].id) { cur = c; break }
            if (cur >= 0 && cur !== t) groupModel.move(cur, t)
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 12

        // ===== 标题行（新建小组在右）=====
        Item {
            width: parent.width
            height: 40
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "小组排行榜"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSection
                    font.bold: true
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            CuteButton {
                tone: "primary"
                text: "＋ 新建小组"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mainWin.dlgGroup.openDialog()
            }
        }

        // ===== 领奖台（暗场舞台 + 射灯）=====
        Rectangle {
            width: parent.width
            height: 368
            radius: Theme.radius
            color: "#f7fafc"
            border.color: "#e4ecf2"
            border.width: 1
            clip: true
            visible: reward.groups.length > 0

            // 深色舞台：铺满整个面板（幕布完整垂落不裁脚）
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height
                clip: true
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height + 40
                    radius: Theme.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#171e2b" }
                        GradientStop { position: 0.75; color: "#27344a" }
                        GradientStop { position: 1.0; color: "#2d3d56" }
                    }
                }
            }
            Podium {
                id: podium
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                topGap: 130
                width: parent.width
                g1: reward.groups.length > 0 ? reward.groups[0] : null
                g2: reward.groups.length > 1 ? reward.groups[1] : null
                g3: reward.groups.length > 2 ? reward.groups[2] : null
            }
        }

        // ===== 全部小组方块（含前三名）=====
        Text {
            text: "全部小组（右键小组可改名/删除）"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
            visible: reward.groups.length > 0
        }
        Flow {
            width: parent.width
            spacing: 12
            Repeater {
                // model = 上面增量同步的 ListModel（不用 reward.groups，理由见 syncGroups 注释）
                model: groupModel
                // 小组卡片：与学生卡片同一套 Card 设计（半透明白玻璃 + 柔和投影 + 悬停上浮）
                delegate: Card {
                    id: gCard
                    property int val: 1          // 自填分值；由下面的 PointsPill 胶囊直接改
                    width: 300
                    radius: Theme.radius
                    cardColor: "#4dffffff"
                    borderColor: "transparent"
                    shadow: true
                    liftOnHover: true

                    // 组员(学号+姓名)全量展示：卡片随组员行数自动长高，不裁剪
                    Column {
                        id: gBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // 原来只有 topMargin，左右贴边 → 文字紧挨卡片边缘。补足四周内边距
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 14
                        spacing: 6
                        Text { // 组名
                            width: parent.width
                            text: model.name
                            color: Theme.textPrimary
                            font.pixelSize: 20
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "总分 " + model.points + " 分 · 组员 " + model.mcount + " 人"
                            color: Theme.accentDark
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            font.family: Theme.fontFamily
                        }
                        // 组员（学号+姓名），自动换行、不裁切
                        Text {
                            visible: model.mcount === 0
                            width: parent.width
                            text: "暂无组员（花名册右键学生 → 移到本组）"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                            wrapMode: Text.WordWrap
                        }
                        Flow {
                            id: memFlow
                            // ⚠️ 不要写成 Repeater { model: model.members }：
                            //    ListModel 在批量 append 时 delegate 的上下文会有短暂未就绪的窗口，
                            //    那次求值会报 "Cannot read property 'members' of undefined"（实测只在加载时出现一次）。
                            //    这里取一次并做保护，model 就绪后绑定会自动重算。
                            property var memItems: (model && model.mstr) ? model.mstr.split("\n") : []
                            visible: model.mcount > 0
                            width: parent.width
                            spacing: 5
                            Repeater {
                                model: memFlow.memItems
                                delegate: Rectangle {
                                    height: 21
                                    radius: Theme.radiusPill
                                    color: "#eef3f8"
                                    border.color: "#dce4ee"
                                    border.width: 1
                                    width: memTxt.implicitWidth + 12
                                    Text {
                                        id: memTxt
                                        // role 里存的就是拼好的「学号 姓名」（见 memberLabels）
                                        text: modelData
                                        anchors.centerIn: parent
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }
                        Item { height: 2; width: 1 }
                        // 自填分值 + 加减
                        Row {
                            spacing: 8
                            // 分值微调胶囊（全站统一样式）；右边两个 RoundBtn 是"应用到本组"的动作，不是调数值
                            PointsPill {
                                id: gVal
                                from: 1
                                to: 99
                                value: gCard.val
                                anchors.verticalCenter: parent.verticalCenter
                                onEdited: gCard.val = value
                            }
                            Item { width: 2; height: 1 }
                            // 与批量操作完全同款：加分 / 扣分 文字按钮（原来是自己画的两个圆钮）
                            CuteButton { tone: "primary"; text: "加分"; anchors.verticalCenter: parent.verticalCenter; onClicked: reward.addGroupPoints(model.gid, gCard.val) }
                            CuteButton { tone: "danger"; text: "扣分"; anchors.verticalCenter: parent.verticalCenter; onClicked: reward.subtractGroupPoints(model.gid, gCard.val) }
                        }
                    }
                    // 卡片高度随内容自动（上 14 + 内容 + 下 16，与新内边距一致）
                    height: gBody.implicitHeight + 30

                    // 右键菜单（整卡右键）
                    // ⚠️ **hoverEnabled 必须 false**：这层 MouseArea 盖满整卡、又是最后声明的（最上层），
                    //    一旦开 hover，Qt 的悬停投递在它这里就终止了 → 下面分值胶囊的 +/− 永远收不到 hover
                    //    （症状：加减号悬停不加粗、点一下才加粗、移开不恢复）。
                    //    右键不受影响：press 与 hover 是两条通道，且胶囊那两个 MouseArea 只认左键。
                    MouseArea {
                        objectName: "cardHoverMa"
                        anchors.fill: parent
                        hoverEnabled: false
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                                mainWin.openGroupMenu(gCard, model.gid, model.name)
                        }
                    }
                }
            }
        }
    }
}
