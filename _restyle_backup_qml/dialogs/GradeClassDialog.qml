import QtQuick
import "../components"

// 新建班级：选「x 年级」+ 阿拉伯数字班级号 → 班级名如「三年级1班」
Modal {
    id: root

    property int gradeIdx: 2
    property string classNo: "1"
    property var onAccept: null
    property var grades: ["一年级", "二年级", "三年级", "四年级", "五年级", "六年级"]

    function openClassDialog(cb) {
        root.title = "新建班级"
        root.gradeIdx = 2
        root.classNo = "1"
        root.onAccept = cb
        root.show()
    }
    // 编辑现有班级名（如「三年级1班」）→ 解析出年级与班级号，仅需点选/微调即可
    function openRenameDialog(cb, currentName) {
        root.title = "重命名班级"
        root.gradeIdx = 2
        root.classNo = "1"
        var s = currentName || ""
        for (var i = 0; i < root.grades.length; i++) {
            if (s.indexOf(root.grades[i]) === 0) {
                root.gradeIdx = i
                var rest = s.slice(root.grades[i].length).replace("班", "").trim()
                if (rest) root.classNo = rest
                break
            }
        }
        root.onAccept = cb
        root.show()
    }

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: 16

            Text {
                text: "年级"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.grades
                    delegate: Rectangle {
                        property bool hov: false
                        width: 68
                        height: 32
                        radius: Theme.radiusPill
                        color: index === root.gradeIdx ? Theme.accent
                             : hov ? "#eef4f8" : "#f0f3f8"
                        border.color: index === root.gradeIdx ? "transparent" : "transparent"
                        Text {
                            text: modelData
                            anchors.centerIn: parent
                            color: index === root.gradeIdx ? "#ffffff" : Theme.textSecondary
                            font.pixelSize: Theme.fontBody
                            font.bold: index === root.gradeIdx
                            font.family: Theme.fontFamily
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.hov = true
                            onExited: parent.hov = false
                            onClicked: root.gradeIdx = index
                        }
                    }
                }
            }

            Text {
                text: "班级序号（阿拉伯数字）"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            Rectangle {
                width: parent.width
                height: 38
                radius: Theme.radiusSmall
                color: Theme.surface
                border.color: noInput.activeFocus ? Theme.accent : Theme.inputBorder
                border.width: 1
                TextInput {
                    id: noInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    text: root.classNo
                    validator: IntValidator { bottom: 1; top: 20 }
                    onTextChanged: root.classNo = text
                }
            }
            Text {
                text: "预览：" + root.grades[root.gradeIdx] + (root.classNo.trim() || "1") + "班"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }

            Row {
                width: parent.width
                spacing: 10
                Item { width: parent.width - 176; height: 1 }
                CuteButton { text: "取消"; onClicked: root.hide() }
                CuteButton {
                    tone: "primary"
                    text: "确定"
                    onClicked: {
                        var no = root.classNo.trim()
                        if (!no) no = "1"
                        if (root.onAccept) root.onAccept(root.grades[root.gradeIdx] + no + "班")
                        root.hide()
                    }
                }
            }
        }
    }
}
