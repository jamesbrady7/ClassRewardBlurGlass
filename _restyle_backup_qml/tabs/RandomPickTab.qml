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
                cardColor: "#80dde9e0"
                borderColor: "#667e9c85"
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text { text: "🎯 抽取学生"; color: Theme.textPrimary; font.pixelSize: Theme.fontBig; font.bold: true; font.family: Theme.fontFamily }
                    Row {
                        width: parent.width
                        spacing: 8
                        Text { text: "抽"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Stepper { id: stuCount; value: 3; max: 50 }
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
                        Stepper { id: stuStep; value: 1; max: 99; heightSize: 24 }
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
                                    Rectangle {
                                        height: 30; radius: 15
                                        color: Theme.pink
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: subTxt.implicitWidth + 20
                                        Text {
                                            id: subTxt
                                            text: "－" + stuStep.value + " 分"
                                            anchors.centerIn: parent
                                            color: "#ffffff"
                                            font.pixelSize: Theme.fontSmall
                                            font.bold: true
                                            font.family: Theme.fontFamily
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustStu(false, stuRow.item)
                                        }
                                    }
                                    Rectangle {
                                        height: 30; radius: 15
                                        color: Theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: addTxt.implicitWidth + 20
                                        Text {
                                            id: addTxt
                                            text: "＋" + stuStep.value + " 分"
                                            anchors.centerIn: parent
                                            color: "#ffffff"
                                            font.pixelSize: Theme.fontSmall
                                            font.bold: true
                                            font.family: Theme.fontFamily
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustStu(true, stuRow.item)
                                        }
                                    }
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
                cardColor: "#80eddcdf"
                borderColor: "#66c08f97"
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text { text: "🏆 抽取小组"; color: Theme.textPrimary; font.pixelSize: Theme.fontBig; font.bold: true; font.family: Theme.fontFamily }
                    Row {
                        width: parent.width
                        spacing: 8
                        Text { text: "抽"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Stepper { id: groupCount; value: 1; max: 20 }
                        Text { text: "个小组"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; font.family: Theme.fontFamily }
                        Item { width: 1; height: 1 }
                        CuteButton { tone: "pink"; text: "抽取"; onClicked: root.grpResult = reward.randomPickGroups(groupCount.value) }
                    }
                    Text { text: "随机选出表现好的小队"; color: Theme.textMuted; font.pixelSize: Theme.fontSmall; font.family: Theme.fontFamily }
                }
            }

            Card {
                width: parent.width
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
                        Stepper { id: grpStep; value: 1; max: 99; heightSize: 24 }
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
                                    Rectangle {
                                        height: 30; radius: 15
                                        color: Theme.pink
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: gsub.implicitWidth + 20
                                        Text {
                                            id: gsub
                                            text: "－" + grpStep.value + " 分"
                                            anchors.centerIn: parent
                                            color: "#ffffff"
                                            font.pixelSize: Theme.fontSmall
                                            font.bold: true
                                            font.family: Theme.fontFamily
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustGrp(false, grpRow.item)
                                        }
                                    }
                                    Rectangle {
                                        height: 30; radius: 15
                                        color: Theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: gadd.implicitWidth + 20
                                        Text {
                                            id: gadd
                                            text: "＋" + grpStep.value + " 分"
                                            anchors.centerIn: parent
                                            color: "#ffffff"
                                            font.pixelSize: Theme.fontSmall
                                            font.bold: true
                                            font.family: Theme.fontFamily
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustGrp(true, grpRow.item)
                                        }
                                    }
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
                tone: root.cat === modelData ? "soft" : "secondary"
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
