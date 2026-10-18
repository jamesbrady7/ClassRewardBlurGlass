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
                        readonly property bool on: index === root.gradeIdx
                        width: 68
                        height: 32
                        radius: Theme.radiusPill
                        // 未选 = 全站统一的半透明白玻璃（#55ffffff，悬停提亮到 #a8ffffff）；
                        // 选中 = 主题实色 + 白字。原来未选用的是 #f0f3f8 实色浅灰，
                        // 与别处的玻璃面不一致，且切换时是硬跳、没有过渡。
                        color: on ? Theme.accent : (hov ? "#a8ffffff" : "#55ffffff")
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            text: modelData
                            anchors.centerIn: parent
                            color: on ? "#ffffff" : Theme.textSecondary
                            font.pixelSize: Theme.fontBody
                            font.bold: on
                            font.family: Theme.fontFamily
                            Behavior on color { ColorAnimation { duration: 140 } }
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

            // 与全站对话框输入框同一套（components/Field.qml）：
            // 半透明白玻璃底、**无描边**、聚焦提亮 + 边缘向内渐隐的内阴影
            Field {
                id: noField
                label: "班级序号（阿拉伯数字）"
                width: parent.width
                input.text: root.classNo
                input.validator: IntValidator { bottom: 1; top: 20 }
                input.onTextChanged: root.classNo = input.text
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
