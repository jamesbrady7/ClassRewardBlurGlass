import QtQuick

// 学生搜索选择器：输入姓名/学号实时过滤；弹出列表高于后续内容（用 z 置顶）。
Item {
    id: root

    property string currentId: ""
    property string currentLabel: ""
    property bool popupOpen: false
    signal picked(string id)

    width: 320
    height: 38

    property string query: ""
    property var filtered: {
        var q = root.query.trim().toLowerCase()
        if (!q) return reward.students
        var arr = []
        for (var i = 0; i < reward.students.length; i++) {
            var s = reward.students[i]
            if (s.name.toLowerCase().indexOf(q) >= 0 || String(s.studentId).toLowerCase().indexOf(q) >= 0)
                arr.push(s)
        }
        return arr
    }

    // 搜索框
    Rectangle {
        id: box
        width: parent.width; height: 38
        radius: Theme.radiusSmall
        color: Theme.surface
        border.color: root.popupOpen ? Theme.accent : Theme.inputBorder
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // 放大镜
        Canvas {
            width: 15; height: 15
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                var c = getContext("2d"); c.reset()
                c.strokeStyle = Theme.textMuted
                c.lineWidth = 1.6
                c.lineCap = "round"
                c.beginPath()
                c.arc(6.2, 6.2, 4.2, 0, Math.PI * 2)
                c.moveTo(9.6, 9.6); c.lineTo(12.8, 12.8)
                c.stroke()
            }
        }

        Text {
            visible: root.currentId === "" && input.text.length === 0
            text: "搜索学生…"
            anchors.left: parent.left; anchors.leftMargin: 34
            anchors.right: parent.right; anchors.rightMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
        }
        Text {
            visible: root.currentId !== "" && input.text.length === 0
            text: "✓ " + root.currentLabel
            anchors.left: parent.left; anchors.leftMargin: 34
            anchors.right: parent.right; anchors.rightMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accentDark
            font.pixelSize: Theme.fontBody
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 34
            anchors.rightMargin: 28
            verticalAlignment: Text.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: Theme.fontBody
            font.family: Theme.fontFamily
            onTextChanged: { root.query = input.text; root.popupOpen = true }
            onAccepted: root.popupOpen = false
        }

        // 打开/关闭
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.popupOpen) root.popupOpen = true
                input.forceActiveFocus()
            }
        }
    }

    // 下拉结果
    Rectangle {
        id: pop
        visible: root.popupOpen
        width: parent.width
        height: Math.min(252, root.filtered.length * 42 + 10)
        anchors.top: box.bottom; anchors.topMargin: 4
        radius: Theme.radiusSmall
        color: Theme.surface
        border.color: Theme.border; border.width: 1
        clip: true
        opacity: root.popupOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ListView {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2
            model: root.filtered
            delegate: Rectangle {
                width: parent.width
                height: 36
                radius: Theme.radiusSmall
                color: root.currentId === modelData.id ? Theme.accentSoft
                     : itemMouse.containsMouse ? Theme.bgTop : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    Text {
                        text: modelData.studentId + "  " + modelData.name + "（可用 " + modelData.available + " 分）"
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.currentId === modelData.id ? Theme.accentDark : Theme.textPrimary
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                        width: parent.width - 40
                    }
                    Text {
                        text: root.currentId === modelData.id ? "✓" : ""
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentId = modelData.id
                        root.currentLabel = modelData.studentId + "  " + modelData.name
                        root.query = ""
                        input.text = ""
                        root.popupOpen = false
                        input.focus = false
                        root.picked(modelData.id)
                    }
                }
            }
        }
    }
}
