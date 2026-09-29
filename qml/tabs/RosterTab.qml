import QtQuick
import QtQuick.Layouts
import "../components"

// 花名册：标题一行；添加/导入/搜索第二行；学生卡片（小组色条纹 + 浅色积分卡 + emoji 圆钮）
ColumnLayout {
    id: root
    spacing: 12

    function edgeColor(g, pos) {
        // 组色 g 的 #RRGGBB；左实→右虚，最右端彻底淡至 0%
        var a = pos < 0.10 ? "72" : pos < 0.30 ? "48" : pos < 0.55 ? "22" : pos < 0.80 ? "0d" : "00"
        return "#" + a + g.slice(1)
    }

    property var filteredStudents: {
        var q = searchInput.text.trim().toLowerCase()
        var arr = []
        for (var i = 0; i < reward.students.length; i++) {
            var s = reward.students[i]
            if (!q || s.name.toLowerCase().indexOf(q) >= 0 || s.studentId.indexOf(q) >= 0)
                arr.push(s)
        }
        return arr
    }

    // 五个操作：emoji + 各自淡色底 + 悬停描边色
    function softBg(action) {
        return action === "undo" ? Theme.purpleSoft
             : action === "history" ? Theme.amberSoft
             : action === "backpack" ? Theme.pinkSoft
             : action === "move" ? Theme.blueSoft
             : Theme.redSoft
    }
    function hue(action) {
        return action === "undo" ? "#7d55d6"
             : action === "history" ? "#cf8d12"
             : action === "backpack" ? "#cf5a90"
             : action === "move" ? "#3f7bd8"
             : "#d64b3b"
    }
    function actionGlyph(action) {
        return action === "undo" ? "🔙"
             : action === "history" ? "🕘"
             : action === "backpack" ? "🎒"
             : action === "move" ? "📦"
             : "🗑"
    }
    function actionHint(action) {
        return action === "undo" ? "撤回最近一次操作"
             : action === "history" ? "查看积分历史"
             : action === "backpack" ? "查看背包奖励"
             : action === "move" ? "移到其他小组"
             : "删除该学生"
    }
    function doAction(sid, name, action) {
        if (action === "undo") mainWin.toast.show(reward.undoLast(sid))
        else if (action === "history") mainWin.dlgHistory.openDialog(sid)
        else if (action === "backpack") mainWin.dlgBackpack.openDialog(sid)
        else if (action === "move") mainWin.dlgMove.openDialog(sid)
        else mainWin.dlgConfirm.openConfirm("确认删除", "删除学生 " + name + "？", function() {
            reward.deleteStudent(sid)
            mainWin.toast.show("已删除 " + name)
        })
    }

    // ===== 第一排：标题 =====
    Row {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        spacing: 10
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "班级花名册"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ===== 第二排：添加 / 导入 / 搜索 / 人数 =====
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 8

        CuteButton {
            tone: "primary"
            text: "＋ 添加学生"
            height: 34
            onClicked: mainWin.dlgStudent.openDialog("")
        }
        CuteButton {
            text: "导入学生"
            height: 34
            onClicked: mainWin.dlgImport.openDialog()
        }

        // 搜索框（固定宽度、紧凑高度）
        Rectangle {
            Layout.preferredWidth: 320
            Layout.maximumWidth: 420
            Layout.alignment: Qt.AlignVCenter
            height: 32
            radius: Theme.radiusPill
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.accent : Theme.inputBorder
            border.width: 1
            Text {
                text: "🔍"
                anchors.left: parent.left; anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontBody
            }
            Text {
                visible: searchInput.text.length === 0
                text: "搜索姓名或学号…"
                anchors.left: parent.left; anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textMuted
                font.pixelSize: Theme.fontBody
                font.family: Theme.fontFamily
            }
            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 40
                anchors.rightMargin: 14
                verticalAlignment: Text.AlignVCenter
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                font.family: Theme.fontFamily
                clip: true
            }
        }

        Item { Layout.fillWidth: true; height: 1 }

        Pill {
            text: "人数：" + root.filteredStudents.length + " / 50"
            bg: Theme.bgTop
            fg: Theme.textSecondary
            fontSize: Theme.fontSmall
        }
    }

    // ===== 学生列表 =====
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        // 上下留出空间：ListView 开了 clip，首行悬停上浮（4px）与投影会被裁掉
        topMargin: 10
        bottomMargin: 10
        model: root.filteredStudents
        // 学生行：改用 **Card 的设计**（毛玻璃圆角 + 柔和投影 + 悬停轻微上浮），
        // 组色渐变**原样保留**在卡片内部当底色 —— 那是分组配色编码，不能丢
        delegate: Card {
            id: card
            property var student: modelData
            width: list.width
            height: 64
            radius: Theme.radius
            // 底色 = 半透明白玻璃。
            // ⚠️ 浓度必须低：玻璃感来自"能透出背后"，72% 白等于一块实心白卡、玻璃感全无。
            //    30% 白时背后被 DWM 糊化的桌面会透上来，才是玻璃。
            cardColor: "#4dffffff"
            borderColor: "transparent"
            shadow: true
            liftOnHover: true

            Row {
                anchors.left: parent.left; anchors.leftMargin: 14
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Avatar { text: card.student.name; bgColor: card.student.groupColor; size: 34 }
                Pill { text: "#" + card.student.studentId; bg: Theme.accentSoft; fg: Theme.accentDark; bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: card.student.name
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBig
                    font.bold: true
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Pill { text: card.student.group; bg: Theme.blueSoft; fg: Theme.blue; anchors.verticalCenter: parent.verticalCenter }

                // 总分 / 可用分：浅色积分卡（与软件浅色清新一致）
                Rectangle {
                    height: 34
                    radius: Theme.radiusPill
                    color: "#f3f7fb"
                    border.color: "#dde6f0"
                    border.width: 1
                    width: scoreRow.implicitWidth + 26
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        id: scoreRow
                        anchors.centerIn: parent
                        spacing: 16
                        Column {
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "总分"
                                color: Theme.textMuted
                                font.pixelSize: 9
                                font.family: Theme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: card.student.earned
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        Rectangle {
                            width: 1; height: 20
                            color: "#dde6f0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "可用"
                                color: Theme.textMuted
                                font.pixelSize: 9
                                font.family: Theme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: card.student.available
                                color: Theme.accentDark
                                font.pixelSize: Theme.fontBody
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
                Item { width: 1; height: 1 }

                // 五个操作：emoji 圆钮，悬停有描边反馈 + 无边框小号说明
                Repeater {
                    model: ["undo", "history", "backpack", "move", "delete"]
                    delegate: RoundBtn {
                        size: 34
                        bg: root.softBg(modelData)
                        fg: root.hue(modelData)
                        glyph: root.actionGlyph(modelData)
                        glyphSize: 18
                        hint: root.actionHint(modelData)
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.doAction(card.student.id, card.student.name, modelData)
                    }
                }
            }
        }
    }
}
