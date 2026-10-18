import QtQuick
import "../components"

// 随机抽取：学生/小组左右分栏；两栏分色，结果各自独立；加减钮立体（减分钮粉底白减号）
Column {
    id: root

    property var stuResult: []
    property var grpResult: []
    property var stuPicked: []          // 当前抽中学生 id（保持顺序），每次数据变化用最新积分重算显示
    property string cat: ""

    spacing: Theme.spacing

    Connections {
        target: reward
        function onDataChanged() { root.resolveStu() }
    }
    function resolveStu() {
        var ids = root.stuPicked
        if (!ids || !ids.length) { root.stuResult = []; return }
        var arr = []
        for (var i = 0; i < ids.length; i++) {
            for (var j = 0; j < reward.students.length; j++) {
                if (reward.students[j].id === ids[i]) { arr.push(reward.students[j]); break }
            }
        }
        root.stuResult = arr
    }

    // 标题行
    Row {
        width: parent.width
        spacing: 10
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "随机抽取"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        id: cols
        width: parent.width
        height: parent.height - (24 + 38 + Theme.spacing * 2)
        spacing: 10

        // ========== 左栏：抽取学生（浅翠）==========
        Item {
            width: parent.width * 0.5 - 5
            height: parent.height

            Card {
                id: stuCtrl
                width: parent.width
                height: 118
                radius: Theme.radius
                // 与前几页同款半透明玻璃卡（原为浅翠实色 + 描边）
                cardColor: Theme.cardGlass
                shadow: true
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text { text: "🎯 抽取学生"; color: Theme.textPrimary; font.pixelSize: Theme.fontBig; font.bold: true; font.family: Theme.fontFamily }
                    Row {
                        width: parent.width
                        spacing: 8
                        Text { text: "抽"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        // 与分值调整同款控件（一个胶囊装下数值 + 上下加减）
                        PointsPill { id: stuCount; from: 1; to: 50; value: 3 }
                        Text { text: "名学生"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Item { width: 1; height: 1 }
                        CuteButton { tone: "primary"; text: "抽取"; onClicked: {
                                var r = reward.randomPickStudents(stuCount.value)
                                var ids = []
                                for (var m = 0; m < r.length; m++) ids.push(r[m].id)
                                root.stuPicked = ids
                                root.resolveStu()
                            } }
                    }
                    Text { text: "低分同学更容易被抽到"; color: Theme.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                }
            }

            Card {
                width: parent.width
                cardColor: Theme.cardGlass
                shadow: true
                anchors.top: stuCtrl.bottom
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                radius: Theme.radius
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Row {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: root.stuResult.length ? "抽中结果 · 按上方分值给所选学生加/减分" : "点击上方「抽取」开始抽学生"
                            width: parent.width - 150
                            elide: Text.ElideRight
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: 1; height: 1 }
                        Text { text: "分值"; color: Theme.textSecondary; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                        PointsPill { id: stuStep; from: 1; to: 99; value: 1; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Flickable {
                        width: parent.width
                        height: parent.height - 40
                        contentHeight: stuCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: stuCol
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.stuResult
                                delegate: Row {
                                    id: stuRow
                                    property var item: modelData
                                    width: parent.width
                                    height: 42
                                    spacing: 8
                                    opacity: 0
                                    Component.onCompleted: opacity = 1
                                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                                    Pill {
                                        text: item.studentId + " " + item.name + "（总分 " + item.earned + " · 可用 " + item.available + " 分）"
                                        bg: Theme.surface
                                        fg: Theme.textPrimary
                                        borderColor: Theme.border
                                        fontSize: Theme.fontBody
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Item { width: 1; height: 1 }
                                    // 与批量操作/小组榜**逐字同款**：加分 / 扣分 文字按钮
                                    // （原来是自己画的实心圆钮，粉底"－N 分"/绿底"＋N 分"，且没有悬停反馈）
                                    // 分值由上方「分值」胶囊统一设定，这两个按钮只负责应用
                                    CuteButton { tone: "primary"; text: "加分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.adjustStu(true, stuRow.item) }
                                    CuteButton { tone: "danger"; text: "扣分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.adjustStu(false, stuRow.item) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ========== 右栏：抽取小组（浅粉）==========
        Item {
            width: parent.width * 0.5 - 5
            height: parent.height

            Card {
                id: grpCtrl
                width: parent.width
                height: 118
                radius: Theme.radius
                // 与前几页同款半透明玻璃卡（原为浅粉实色 + 描边）
                cardColor: Theme.cardGlass
                shadow: true
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text { text: "🏆 抽取小组"; color: Theme.textPrimary; font.pixelSize: Theme.fontBig; font.bold: true; font.family: Theme.fontFamily }
                    Row {
                        width: parent.width
                        spacing: 8
                        Text { text: "抽"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        PointsPill { id: groupCount; from: 1; to: 20; value: 1 }
                        Text { text: "个小组"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Item { width: 1; height: 1 }
                        CuteButton { tone: "pink"; text: "抽取"; onClicked: root.grpResult = reward.randomPickGroups(groupCount.value) }
                    }
                    Text { text: "随机选出表现好的小队"; color: Theme.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                }
            }

            Card {
                width: parent.width
                cardColor: Theme.cardGlass
                shadow: true
                anchors.top: grpCtrl.bottom
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                radius: Theme.radius
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Row {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: root.grpResult.length ? "抽中结果" : "点击上方「抽取」开始抽小组"
                            width: parent.width - 150
                            elide: Text.ElideRight
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: 1; height: 1 }
                        Text { text: "分值"; color: Theme.textSecondary; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                        PointsPill { id: grpStep; from: 1; to: 99; value: 1; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Flickable {
                        width: parent.width
                        height: parent.height - 40
                        contentHeight: grpCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: grpCol
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.grpResult
                                delegate: Row {
                                    id: grpRow
                                    property var item: modelData
                                    width: parent.width
                                    height: 42
                                    spacing: 8
                                    opacity: 0
                                    Component.onCompleted: opacity = 1
                                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                                    Pill {
                                        text: "🏆 " + item.name
                                        bg: Theme.surface
                                        fg: Theme.textPrimary
                                        borderColor: Theme.border
                                        fontSize: Theme.fontBody
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Item { width: 1; height: 1 }
                                    // 同上：加分 / 扣分 文字按钮（与批量操作、小组榜一致）
                                    CuteButton { tone: "primary"; text: "加分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.adjustGrp(true, grpRow.item) }
                                    CuteButton { tone: "danger"; text: "扣分"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.adjustGrp(false, grpRow.item) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 维度选择（学生加减分需要）
    Row {
        width: parent.width
        height: 38
        spacing: 6
        Text { text: "操作维度："; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
        Repeater {
            model: reward.categories
            delegate: CuteButton {
                // ⚠️ 原来写的是 soft / secondary —— CuteButton 里 filled = tone!=="secondary"
                //    && tone!=="soft"，**这两档都是未填充的玻璃**，选中与未选中长得一模一样，
                //    所以点了看着"无法选中"（数据分析的「全班」按钮当初也是这个坑）。
                //    改成 primary（实色），与批量操作页的分类标签完全一致。
                tone: root.cat === modelData ? "primary" : "secondary"
                text: modelData
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.cat = modelData
            }
        }
    }

    function adjustStu(isAdd, item) {
        if (!root.cat) { mainWin.toast.show("请先选择操作维度", 2000, true); return }
        var n = stuStep.value
        reward.pointChange(item.id, n, isAdd, root.cat)
        mainWin.toast.show((isAdd ? "＋" + n + "分：" : "－" + n + "分：") + item.name)
    }
    function adjustGrp(isAdd, item) {
        var n = grpStep.value
        if (isAdd) reward.addGroupPoints(item.id, n); else reward.subtractGroupPoints(item.id, n)
        mainWin.toast.show((isAdd ? "＋" + n + "分：" : "－" + n + "分：") + item.name)
    }
}
