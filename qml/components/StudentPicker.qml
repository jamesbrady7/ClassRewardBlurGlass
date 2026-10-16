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
        // 形状改成与**花名册搜索栏**一致的全圆胶囊（原来 radiusSmall = 圆角矩形）；
        // 配色/悬停/展开/内阴影等效果一律不变。高度仍是 38（花名册那个是 32）。
        radius: Theme.radiusPill
        // 平时=半透明白玻璃（原来是 Theme.surface 纯白不透明），浓度与同排的三颗图标钮、
        // 以及奖券的删除钮一致（都是 #55ffffff 这一档）；悬停/展开时提亮
        color: root.popupOpen ? "#e0ffffff" : (boxMa.containsMouse ? "#a8ffffff" : "#55ffffff")
        // 只有展开/焦点态用硬边框（主题灰，原来是强调色绿）；平时交给下面那圈"向内渐隐的白边"，
        // 不再画 1px 硬边——硬边在这一片浅色玻璃上会读成"框了一条白线"
        border.color: Theme.textMuted
        border.width: root.popupOpen ? 1 : 0
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // 未点击时的边缘：**向内渐隐的白边**
        // 多层内缩的圆角描边叠出衰减（同 SoftRectShadow 的手法：本 Qt 的 Canvas 没有高斯模糊）。
        // 每条描边都从 box 内侧起画（inset 从 1 起、线宽 1），**不会溢出容器**。
        Canvas {
            id: softEdge
            anchors.fill: parent
            visible: !root.popupOpen
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height, base = box.radius, N = 5
                for (var i = 0; i < N; i++) {
                    var a = 0.58 * Math.pow(1 - i / N, 1.4)      // 贴边最亮，向内快速衰减
                    var ins = i + 1
                    var x = ins, y = ins, ww = w - 2 * ins, hh = h - 2 * ins
                    // ⚠️ 必须钳到 min(ww,hh)/2：radius 是 radiusPill(=999) 时，
                    //    `base - ins` 会远大于半个框，二次贝塞尔路径直接画反、形状崩掉。
                    //    圆角矩形时 min() 取到的仍是 base，行为不变。
                    var rr = Math.max(1, Math.min(base, ww / 2, hh / 2))
                    ctx.strokeStyle = "rgba(255,255,255," + a.toFixed(3) + ")"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(x + rr, y)
                    ctx.lineTo(x + ww - rr, y); ctx.quadraticCurveTo(x + ww, y, x + ww, y + rr)
                    ctx.lineTo(x + ww, y + hh - rr); ctx.quadraticCurveTo(x + ww, y + hh, x + ww - rr, y + hh)
                    ctx.lineTo(x + rr, y + hh); ctx.quadraticCurveTo(x, y + hh, x, y + hh - rr)
                    ctx.lineTo(x, y + rr); ctx.quadraticCurveTo(x, y, x + rr, y)
                    ctx.closePath()
                    ctx.stroke()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

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
