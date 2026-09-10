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
    function catColor(cat) {
        return cat === "普通" ? Theme.blueSoft
             : cat === "稀有" ? Theme.purpleSoft
             : cat === "史诗" ? Theme.amberSoft
             : Theme.redSoft
    }
    function catFg(cat) {
        return cat === "普通" ? Theme.blue
             : cat === "稀有" ? Theme.purple
             : cat === "史诗" ? Theme.amber
             : Theme.red
    }
    // 奖券底：等级色的半透明底色（透明渐变感，无边框盒子）
    function tintCat(cat) {
        return "#32" + root.catFg(cat).slice(1)
    }

    spacing: Theme.spacing

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

    // 学生选择 + 学生操作（选择行整体置顶，弹出列表不被下方奖券遮挡）
    Row {
        width: parent.width
        spacing: 8
        z: picker.popupOpen ? 80 : 0
        StudentPicker {
            id: picker
            onPicked: root.currentStudentId = id
        }
        IconChip {
            icon: "undo"
            text: "撤回"
            fg: Theme.amber
            bg: Theme.amberSoft
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { if (root.currentStudentId) mainWin.toast.show(reward.undoLast(root.currentStudentId)); else mainWin.toast.show("请先选择学生") }
        }
        IconChip {
            icon: "clock"
            text: "历史"
            fg: Theme.blue
            bg: Theme.blueSoft
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { if (root.currentStudentId) mainWin.dlgHistory.openDialog(root.currentStudentId); else mainWin.toast.show("请先选择学生") }
        }
        IconChip {
            icon: "bag"
            text: "背包"
            fg: Theme.purple
            bg: Theme.purpleSoft
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { if (root.currentStudentId) mainWin.dlgBackpack.openDialog(root.currentStudentId); else mainWin.toast.show("请先选择学生") }
        }
        Item { width: 1; height: 1 }
        CuteButton {
            tone: "primary"
            text: "＋ 新增奖励"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: mainWin.dlgReward.openDialog()
        }
    }

    // 分类筛选：文字与整块配色跟随等级（选中=实底反白，未选中=该等级淡底+同色文字）
    Row {
        width: parent.width
        spacing: 6
        Repeater {
            model: ["all", "普通", "稀有", "史诗", "传说"]
            delegate: Rectangle {
                id: fb
                property bool hov: false
                property bool act: root.cat === modelData
                // 底色=各分类色（全部=正文深灰）；未选中=半透明彩底，选中=全彩+白色描边圈
                function col() { return modelData === "all" ? Theme.textPrimary : root.catFg(modelData) }
                function tinted(hex) { return "#" + hex + fb.col().slice(1) }
                width: txt.implicitWidth + 34
                height: 36
                radius: Theme.radiusSmall
                color: fb.act ? fb.col() : (fb.hov ? fb.tinted("d6") : fb.tinted("a8"))
                border.width: fb.act ? 2 : 0
                border.color: "#ffffff"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    id: txt
                    text: modelData === "all" ? "全部" : modelData
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    font.family: Theme.fontFamily
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: fb.hov = true
                    onExited: fb.hov = false
                    onClicked: root.cat = modelData
                }
            }
        }
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
                    color: "#55ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🗑"; anchors.centerIn: parent; font.pixelSize: 14 }
                    MouseArea {
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
        color: Theme.amberSoft
        border.color: Theme.amber
        border.width: 2
        Row {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text { text: "🎁 盲盒券（10 分）· 随机抽取奖励"; color: Theme.amber; font.pixelSize: Theme.fontBody; font.bold: true; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 1; height: 1 }
            CuteButton {
                tone: "primary"
                text: "兑换盲盒"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (!root.currentStudentId) { mainWin.toast.show("请先选择学生"); return }
                    mainWin.toast.show(reward.buyBlindBox(root.currentStudentId))
                }
            }
        }
    }
}
