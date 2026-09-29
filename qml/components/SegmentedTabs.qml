import QtQuick

// 分段标签：**照搬毛玻璃原型的 SegmentedTabs** —— 底槽 + 滑动白胶囊（移动时带拉伸形变）。
// 与原型的差异只有两处必要的适配：
//   ① 颜色走本应用的 Theme token（原型是 theme.fillShell / fillPill）
//   ② 增加了 rightClicked 信号：原组件没有右键，而本应用的班级胶囊**右键可改名/删除**，这个能力必须留住
Item {
    id: root
    property var labels: []
    property int currentIndex: 0
    // 可选：每一格的主色（分类色这类**有语义**的颜色）。传了之后：
    //   · 滑动胶囊取"当前格"的颜色（切格时颜色跟着渐变）
    //   · 未选中的标签用各自的主色 → 5 个分类色依然一眼可辨，分类功能不丢
    // 不传则保持原型原样（白胶囊 + 常规文字色）
    property var colors: []
    // 每格宽度：默认按最长标签自动撑开（原型是固定 96，本应用班名长短不一）
    property real seg: autoSeg
    signal activated(int index)
    signal rightClicked(int index, Item tabItem)

    implicitHeight: 36
    implicitWidth: seg * labels.length + 8

    TextMetrics {
        id: tm
        font.pixelSize: Theme.fontBody
        font.family: Theme.fontFamily
        font.weight: Font.DemiBold
    }
    readonly property real autoSeg: {
        var m = 0
        for (var i = 0; i < labels.length; i++) {
            tm.text = labels[i]
            m = Math.max(m, tm.advanceWidth)
        }
        return Math.max(72, Math.ceil(m) + 36)
    }

    // 位移进度（以「格」为单位的连续值）—— 唯一动画源；形变由它派生 → 位移与形变天然同步
    property real pos: currentIndex
    Behavior on pos { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    readonly property real frac: pos - Math.floor(pos)
    // pow(,0.6) 让峰值更"平台"：形变升得快、保持久（OutCubic 下 pos=0.5 只在前 20% 出现，否则一闪而过）
    readonly property real stretch: Math.pow(4 * frac * (1 - frac), 0.6)
    readonly property bool useColors: colors !== undefined && colors.length === labels.length

    // 底槽
    Rectangle {
        id: shell
        anchors.fill: parent
        radius: height / 2
        color: Theme.fillShell
    }

    // 滑动胶囊：高不变、只拉长长度；位置与形变同源于 pos（居中补偿 → 两侧对称拉伸、两端不越界）
    Rectangle {
        id: pill
        y: 4
        height: parent.height - 8
        radius: height / 2
        color: root.useColors ? root.colors[root.currentIndex] : Theme.fillPill
        // 切换分类时胶囊颜色跟着渐变（不是主题色，不需要跟 nightT 同步，故可放心挂动画）
        Behavior on color { ColorAnimation { duration: 260 } }
        width: root.seg + root.stretch * 36
        x: 4 + root.pos * root.seg - root.stretch * 18
    }

    Row {
        anchors.fill: parent
        // ⚠️ 必须和胶囊用同一套坐标系：胶囊是 `x = 4 + pos*seg`（外壳内有 4px 边距），
        //    而 Row 默认从 0 铺 → 文字会比胶囊中心偏左 4px（就是"没和文字居中对齐"）。
        //    这里补上同样的 4px 边距，n*seg 正好等于 width-8，右边也不会溢出。
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        Repeater {
            model: root.labels
            delegate: Item {
                id: tab
                required property int index
                required property string modelData
                width: root.seg
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: tab.modelData
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    font.weight: root.currentIndex === tab.index ? Font.DemiBold : Font.Normal
                    color: root.currentIndex === tab.index
                           ? (root.useColors ? "#ffffff" : Theme.textPrimary)
                           : (root.useColors ? root.colors[tab.index] : Theme.textSecondary)
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: function(m) {
                        // 右键：交给页面弹班级菜单（改名/删除）——原型没有这个，是本应用原有的能力
                        if (m.button === Qt.RightButton)
                            root.rightClicked(tab.index, tab)
                    }
                    onClicked: function(m) {
                        if (m.button !== Qt.LeftButton) return   // 右键不切页
                        root.currentIndex = tab.index
                        root.activated(tab.index)
                    }
                }
            }
        }
    }
}
