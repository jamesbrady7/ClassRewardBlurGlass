import QtQuick
import QtQuick.Controls

// 学生搜索选择器：输入姓名/学号实时过滤。
// 下拉用 Popup —— ①自带「点别处关闭 / Esc 关闭」（原来只能点中某一项或按回车才收，
// 点别处不会消失）；②渲染在窗口覆盖层，天然盖住下方其它内容（不再需要父级调 z）。
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
        // 平时=半透明白玻璃（原来是 Theme.surface 纯白不透明），浓度与同排的三颗图标钮、
        // 以及奖券的删除钮一致（都是 #55ffffff 这一档）；悬停/展开时提亮
        color: root.popupOpen ? "#e0ffffff" : (boxMa.containsMouse ? "#a8ffffff" : "#55ffffff")
        // 焦点边框用**主题里的灰**（原来是强调色绿 #0fa88f，和这套浅色玻璃不搭）；
        // 悬停也给一档更深的灰，形成"灰阶阶梯"：静止 inputBorder → 悬停 → 展开 textMuted
        border.color: root.popupOpen ? Theme.textMuted
                                    : (boxMa.containsMouse ? "#bcc5d2" : Theme.inputBorder)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // 展开时由边框**向框内渐隐**的内阴影（内凹感）：贴边最重、约 55% 处消失，
        // 所以只压住上半边的"内壁"，不会糊到文字。声明在文字之前=压在文字下面。
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, box.radius - 1)
            visible: opacity > 0.01
            opacity: root.popupOpen ? 1 : 0
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(0.35, 0.40, 0.50, 0.15) }
                GradientStop { position: 0.55; color: Qt.rgba(0.35, 0.40, 0.50, 0.0) }
            }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }

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

        // 打开/关闭（hoverEnabled 供上面的底色高亮用）
        MouseArea {
            id: boxMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.popupOpen) root.popupOpen = true
                input.forceActiveFocus()
            }
        }
    }

    // popupOpen 是唯一开关：外部（包括 Popup 自己关闭时）都只改这个属性
    onPopupOpenChanged: popupOpen ? pop.open() : pop.close()

    // 下拉结果：Popup = 窗口覆盖层 + 「点别处/按 Esc 自动关闭」
    Popup {
        id: pop
        y: box.height + 4
        width: root.width
        height: Math.min(252, root.filtered.length * 42 + 10)
        padding: 5
        // ⚠️ 用 CloseOnPressOutsideParent（不是 CloseOnPressOutside）：
        //    搜索框本身在 popup 之外，用后者的话点搜索框会"先关再被 MouseArea 重新打开"（闪一下）；
        //    前者只在按到**本组件之外**时才关 → 点搜索框保持展开，点别处关掉。
        closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape
        // 只保留淡入淡出（与原来的 140ms 一致），关掉控件自带的缩放/滑动
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120; easing.type: Easing.OutCubic } }
        background: Rectangle {
            radius: Theme.radiusSmall
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }
        onClosed: {
            root.popupOpen = false
            input.focus = false
        }

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 2
            model: root.filtered
            delegate: Rectangle {
                width: parent.width
                height: 36
                radius: Theme.radiusSmall
                // 悬停=明确的浅色高亮（原来用 Theme.bgTop，压在纯白弹层上几乎看不出）；
                // 选中=薄荷底 + 深色字 + 右侧 ✓（与悬停区分开）
                // ⚠️ **这里绝不能挂 Behavior 淡入淡出**：鼠标快速划过列表时，上一行还在淡出、
                //    下一行已在淡入，一串半亮行叠成拖影，看起来就是"高亮在闪"。
                //    全站的约定也是——Behavior 只挂单个控件（按钮/Tab/导航项），列表行一律瞬时切换。
                color: root.currentId === modelData.id ? Theme.accentSoft
                     : itemMouse.containsMouse ? "#e9eef5" : "transparent"
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
