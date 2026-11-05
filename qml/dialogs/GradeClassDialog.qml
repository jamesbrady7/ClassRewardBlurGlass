import QtQuick
import "../components"

// 新建班级：选「x 年级」+ 阿拉伯数字班级号 → 班级名如「三年级1班」
Modal {
    id: root

    // 半透明面板：50% 白玻璃（和花名册分数胶囊同档），能透出被压暗的页面
    panelColor: Theme.fillGlass

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
            // 年级选择：与批量/随机页「操作分类」的六个维度标签完全同款
            // （CuteButton + whiteHighlight：选中近实白 + 深字，未选半透明白玻璃）
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.grades
                    delegate: CuteButton {
                        tone: "secondary"
                        whiteHighlight: index === root.gradeIdx
                        text: modelData
                        onClicked: root.gradeIdx = index
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
                    fillScheme: "soda"          // 原型长条按钮 03（薄荷苏打）
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
