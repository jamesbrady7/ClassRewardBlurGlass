import QtQuick
import "../components"

// 积分商店：选学生 → 浏览奖品兑换 + 盲盒
Column {
    id: root

    property string cat: "all"
    property string currentStudentId: ""

    property var filteredRewards: {
        var arr = []
        for (var i = 0; i < reward.rewards.length; i++) {
            var r = reward.rewards[i]
            if (r.blindExcluded) continue
            if (root.cat === "all" || r.category === root.cat) arr.push(r)
        }
        return arr
    }
    // 分类色映射已挪到 Theme（catSoft / catFg）—— 商店和背包共用同一份，别再各写一套。
    // 原来这里还有一份 catColor，全文件没人用，一并删掉。
    // 未知分类兜底成红（保持原行为；Theme.catFg 对未知返回空串，好让调用方自己决定兜底）。
    function catFg(cat) {
        return Theme.catFg(cat) || Theme.red
    }
    // 奖券底：等级色的半透明底色（透明渐变感，无边框盒子）
    function tintCat(cat) {
        return "#32" + root.catFg(cat).slice(1)
    }

    spacing: Theme.spacing

    // 切走本 tab 时收起学生下拉。
    // ⚠️ 下拉是 Popup，挂在**窗口覆盖层**（z=1000001），不随页面 visible 一起隐藏——
    //    不主动收的话它会悬在别的 tab 页面上，切回来时层级/内容也是错的。
    onVisibleChanged: if (!visible && picker.popupOpen) picker.popupOpen = false

    Row {
        width: parent.width
        spacing: 10
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "积分商店"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 1; height: 1 }
    }

    // 学生选择 + 学生操作（下拉现在是 Popup，渲染在窗口覆盖层，不用再调 z）
    Row {
        width: parent.width
        spacing: 8
        StudentPicker {
            id: picker
            onPicked: root.currentStudentId = id
            // 选中学生后，**在搜索框内、学生名字右侧**出现这三颗针对该学生的按钮
            // （空状态时不显示；× 仍然可以直接清掉选中）
            actions: Component {
                Row {
                    spacing: 4
                    RoundBtn {
                        size: 28; bg: Theme.purpleSoft; fg: "#7d55d6"; glyph: "🔙"; glyphSize: 14
                        hint: "撤销这个学生的上一步"
                        onClicked: mainWin.toast.show(reward.undoLast(picker.currentId))
                    }
                    RoundBtn {
                        size: 28; bg: Theme.amberSoft; fg: "#cf8d12"; glyph: "🕘"; glyphSize: 14
                        hint: "这个学生的积分历史"
                        onClicked: mainWin.dlgHistory.openDialog(picker.currentId)
                    }
                    RoundBtn {
                        size: 28; bg: Theme.pinkSoft; fg: "#cf5a90"; glyph: "🎒"; glyphSize: 14
                        hint: "这个学生的奖励背包"
                        onClicked: mainWin.dlgBackpack.openDialog(picker.currentId)
                    }
                }
            }
        }
        // 纯图标按钮：底色同本页奖券的删除钮（白色半透明），只留符号、不要文字
        // 搜索框外只保留一颗「撤销上一步」——**不限学生**，撤销全班最近发生的那一笔
        //（针对某个学生的撤销/历史/背包已经挪进搜索框内、学生名字后面）
        RoundBtn {
            size: 34
            bg: Theme.purpleSoft
            fg: "#7d55d6"
            glyph: "🔙"
            glyphSize: 18
            hint: "撤销上一步（全班）"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: mainWin.toast.show(reward.undoLastAny())
        }
        Item { width: 1; height: 1 }
        CuteButton {
            tone: "primary"
            text: "＋ 新增奖励"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: mainWin.dlgReward.openDialog()
        }
    }

    // 分类筛选：换用原型的**分段 Tab**（底槽 + 滑动胶囊 + 移动拉伸形变），
    // 但**保留各分类的颜色**（颜色本身是分类标识）：
    //   滑动胶囊取当前分类色、切分类时颜色渐变；未选中的标签用各自分类色 → 5 色一眼可辨
    SegmentedTabs {
        labels: ["全部", "普通", "稀有", "史诗", "传说"]
        colors: [Theme.textPrimary, Theme.blue, Theme.purple, Theme.amber, Theme.red]
        currentIndex: Math.max(0, ["all", "普通", "稀有", "史诗", "传说"].indexOf(root.cat))
        onActivated: function(i) { root.cat = ["all", "普通", "稀有", "史诗", "传说"][i] }
    }

    // 奖励列表
    ListView {
        id: rewardList
        width: parent.width
        height: parent.height - (40 + 40 + 40 + 54 + Theme.spacing * 4)
        clip: true
        spacing: 8
        model: root.filteredRewards
        delegate: Rectangle {
            width: rewardList.width
            height: 54
            radius: Theme.radius
            // 奖券：等级色透明底 + 无边框（等级靠底色与左侧实心标签表达）
            color: root.tintCat(modelData.category)
            border.width: 0
            Row {
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle { // 等级标签（实底）
                    width: 64; height: 30; radius: Theme.radiusPill
                    color: root.catFg(modelData.category)
                    Text {
                        text: modelData.category
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.fontFamily
                    }
                }
                Text {
                    text: modelData.name + "（" + modelData.cost + " 分）"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: parent.width - 210
                }
                Item { width: 1; height: 1 }
                CuteButton {
                    tone: "primary"
                    text: "兑换"
                    implicitWidth: 64
                    implicitHeight: 30
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.redeem(modelData)
                }
                Rectangle {
                    width: 30; height: 30; radius: 15
                    // 悬停提亮（白玻璃底提不动，直接换更亮的白）
                    // ⚠️ 不加 Behavior：这个钮在列表行里，扫过整列时同样会拖出"半亮拖影"
                    color: delMa.containsMouse ? "#a8ffffff" : "#55ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🗑"; anchors.centerIn: parent; font.pixelSize: 14 }
                    MouseArea {
                        id: delMa
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: mainWin.dlgConfirm.openConfirm("删除奖励", "删除「" + modelData.name + "」？", function() { reward.deleteReward(modelData.id) })
                    }
                }
            }
        }
    }

    function redeem(r) {
        if (!root.currentStudentId) { mainWin.toast.show("请先选择学生"); return }
        var err = reward.redeemReward(root.currentStudentId, r.id)
        if (err) mainWin.toast.show(err)
        else mainWin.toast.show("兑换成功：" + r.name)
    }

    // 盲盒
    Rectangle {
        width: parent.width
        height: 50
        radius: Theme.radius
        // 半透明粉底 + 无边框（原来是 amberSoft 实色 + 2px amber 描边）：
        // 底色取主题粉 #e76a9e 的 20% 透明度（同奖券底色的 tintCat 手法），文字色跟着底色一起改成粉
        color: "#33" + Theme.pink.slice(1)
        border.width: 0
        // 文字靠左、按钮**贴最右**（原来用 Row + 1px 弹簧，按钮实际紧跟在文字后面）
        Text {
            text: "🎁 盲盒券（10 分）· 随机抽取奖励"
            color: Theme.pink
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
        }
        CuteButton {
            tone: "primary"
            text: "兑换盲盒"
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                if (!root.currentStudentId) { mainWin.toast.show("请先选择学生"); return }
                mainWin.toast.show(reward.buyBlindBox(root.currentStudentId))
            }
        }
    }
}
