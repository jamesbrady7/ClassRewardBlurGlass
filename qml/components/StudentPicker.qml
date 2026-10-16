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

    // 搜索框：组件见 components/SearchBox.qml —— 全站统一（形状/配色/悬停/展开/内阴影），
    // 这里只负责把它接到 picker 的状态上（query / 展开 / 选中回显 / 点框即展开）。
    SearchBox {
        id: box
        width: parent.width
        height: 38
        placeholder: "搜索学生…"
        // 已选中且输入框为空时，改显示"✓ 学号 姓名"
        doneLabel: (root.currentId !== "" && box.text.length === 0)
                   ? ("✓ " + root.currentLabel) : ""
        active: root.popupOpen
        onTextEdited: (t) => { root.query = t; root.popupOpen = true }
        onAccepted: root.popupOpen = false
        onClicked: if (!root.popupOpen) root.popupOpen = true
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
            box.input.focus = false
        }

        ListView {
            anchors.fill: parent
            clip: true
            spacing: 2
            model: root.filtered
            delegate: Rectangle {
                id: rowRect
                width: parent.width
                height: 36
                radius: Theme.radiusSmall
                readonly property bool sel: root.currentId === modelData.id
                // 悬停或选中（"热"态）：文字放大 + 加粗；移开/取消选中自动恢复
                readonly property bool hot: itemMouse.containsMouse || sel
                readonly property string label: modelData.studentId + "  " + modelData.name
                                                + "（可用 " + modelData.available + " 分）"
                readonly property color fg: sel ? Theme.accentDark : Theme.textPrimary
                // 字号有**过渡**（150ms）：直接绑 hot 会"啪"地跳，很突兀。
                property real fs: hot ? Theme.fontSmall + 1 : Theme.fontSmall
                Behavior on fs { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
                    // 文字层：字号走上面的 fs 动画；**加粗本身是离散的没法插值**，
                    // 所以用"常规/加粗两行叠着交叉淡化"来补——合起来整个过程是连续的，不是啪地跳。
                    // 两层都是 anchors.fill + 显式宽度的容器 → 不引起任何布局回流（不会诱发悬停抖动）。
                    Item {
                        width: parent.width - 40
                        height: parent.height
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: rowRect.label
                            color: rowRect.fg
                            font.pixelSize: rowRect.fs
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            opacity: rowRect.hot ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: rowRect.label
                            color: rowRect.fg
                            font.pixelSize: rowRect.fs
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            opacity: rowRect.hot ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text {
                        text: "✓"                       // 常驻，只淡入淡出（原来是空串↔"✓"直接跳）
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                        font.bold: true
                        font.family: Theme.fontFamily
                        opacity: rowRect.sel ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
                        box.text = ""
                        root.popupOpen = false
                        box.input.focus = false
                        root.picked(modelData.id)
                    }
                }
            }
        }
    }
}
