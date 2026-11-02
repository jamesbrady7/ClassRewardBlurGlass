import QtQuick

// 左侧导航：**照搬毛玻璃原型 NavRail 的效果**——"灯从玻璃后亮起"。
//   静止=灭；悬停=半亮(0.48)；点击=最亮(1.0)。没有实底胶囊，选中靠**光**表达。
// 外壳仍是毛玻璃（本应用的内容区没有外层玻璃面板，所以导航自带一块）。
Item {
    id: root

    property var titles: []
    property int currentIndex: 0
    property Item blurSource: null      // 毛玻璃的模糊源（Main.qml 传 backgroundLayer）
    signal activated(int index)

    // 点亮/熄灭时长：700ms InOutQuad = 能看清"由暗到明"的过程，像拧调光旋钮
    property int rampMs: 700
    property real hoverLit: 0.48        // 悬停档位（点击=1，静止=0）
    property int hoverRampMs: 110       // 悬停点亮：要"扫过就亮"，所以很短（点击填满仍走 rampMs=700）

    // 每个 tab 的图标与配色（icon 取自 CanvasIcon 的矢量图标集）
    readonly property var metas: [
        { icon: "user",    soft: "#fdeee1", deep: "#d0803f" },   // 花名册
        { icon: "trophy",  soft: "#e2f5ec", deep: "#37a184" },   // 小组榜
        { icon: "sparkle", soft: "#ebe9fc", deep: "#6f66d8" },   // 随机抽取
        { icon: "sliders", soft: "#e5effc", deep: "#4a7fd6" },   // 批量操作
        { icon: "gift",    soft: "#fde9f2", deep: "#c85f96" },   // 积分商店
        { icon: "check",   soft: "#fdf3e0", deep: "#c08a2e" },   // 每日历史
        { icon: "chart",   soft: "#e9f3f6", deep: "#3f7f96" },   // 数据分析
        { icon: "toolbox", soft: "#eceef3", deep: "#5f6b85" }    // 工具箱
    ]

    // ── 毛玻璃外壳（本应用的内容区没有外层玻璃面板，导航自带一块）──
    FrostedPanel {
        id: shell
        anchors.fill: parent
        source: root.blurSource
        radius: Theme.radius
        tint: Theme.navTint
        blur: 1.0
        glassBlur: !systemGlass       // 穿透模式：模糊交给 DWM，这里只留半透明 tint
        shadow: true
        shadowColor: "#33202830"
    }

    // 隐藏的量尺：取**最长标题**（四个字）在选中字重下的宽度。
    // 所有 tab 的文字列都按这个宽度排 → 三字/四字标题占同样的宽度，右边缘也对齐。
    Text {
        id: titleMeasure
        visible: false
        text: root.titles.reduce(function(a, b) {
            return (b && b.length > (a ? a.length : 0)) ? b : a
        }, "")
        font.pixelSize: 15
        font.family: Theme.fontFamily
        font.weight: Font.DemiBold        // 选中态最宽，按它量
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: 10
        spacing: 4

        Repeater {
            model: root.titles.length

            delegate: Item {
                id: navItem
                required property int index
                readonly property var meta: root.metas[index % root.metas.length]
                readonly property bool selected: root.currentIndex === index
                readonly property bool hovered: navMa.containsMouse

                width: parent.width
                height: 44

                // 灯从玻璃后亮起：用**两条各自固定时长的动画**取大（不是一个会变的 duration）
                property real hoverP: 0
                property int hoverMs: root.hoverRampMs
                Behavior on hoverP {
                    NumberAnimation { duration: navItem.hoverMs; easing.type: Easing.InOutQuad }
                }
                function syncHover() {
                    var on = navItem.hovered && !navItem.selected
                    navItem.hoverMs = on ? root.hoverRampMs : root.rampMs
                    navItem.hoverP = on ? 1 : 0
                }
                onHoveredChanged: navItem.syncHover()
                onSelectedChanged: navItem.syncHover()
                property real selP: navItem.selected ? 1 : 0
                Behavior on selP {
                    NumberAnimation { duration: root.rampMs; easing.type: Easing.InOutQuad }
                }
                // 点亮进度 = 悬停档 与 选中档 取大；它同时决定亮度与光晕半径
                readonly property real glowP: Math.max(navItem.hoverP * root.hoverLit, navItem.selP)

                Canvas {
                    id: navGlow
                    anchors.fill: parent
                    property real p: navItem.glowP
                    onPChanged: requestPaint()      // 半径随 p 变，必须重绘
                    opacity: navItem.glowP
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var w = width, h = height
                        if (w < 4 || h < 4) return
                        if (p <= 0.002) return       // 完全无光，不必构造退化渐变
                        // 形状固定为满尺寸（圆角矩形裁切），只有里面的光在涨：
                        // p 小=中间一小团虚边光斑，p=1=铺满整条并"填实"
                        var k = p
                        var r = 12
                        ctx.beginPath()
                        ctx.moveTo(r, 0); ctx.lineTo(w - r, 0); ctx.quadraticCurveTo(w, 0, w, r)
                        ctx.lineTo(w, h - r); ctx.quadraticCurveTo(w, h, w - r, h)
                        ctx.lineTo(r, h); ctx.quadraticCurveTo(0, h, 0, h - r)
                        ctx.lineTo(0, r); ctx.quadraticCurveTo(0, 0, r, 0)
                        ctx.closePath(); ctx.clip()
                        var cMain = "rgba(255,255,255,0.74)"
                        var cMid  = "rgba(230,234,255,0.24)"
                        var cLamp = "rgba(255,255,255,0.50)"
                        var R = w * 0.64 * k
                        var g = ctx.createRadialGradient(w / 2, h / 2, R * (0.09 + 0.26 * k), w / 2, h / 2, R)
                        g.addColorStop(0, cMain)
                        g.addColorStop(0.55, cMid)
                        g.addColorStop(1, "rgba(255,255,255,0)")
                        ctx.fillStyle = g; ctx.fillRect(0, 0, w, h)
                        // 底部灯芯亮核（灯自下亮起向上晕）
                        var g2 = ctx.createRadialGradient(w / 2, h, 0, w / 2, h, w * 0.42 * k)
                        g2.addColorStop(0, cLamp)
                        g2.addColorStop(1, "rgba(255,255,255,0)")
                        ctx.fillStyle = g2; ctx.fillRect(0, 0, w, h)
                    }
                }

                Row {
                    id: navContent
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {      // 图标方片（与原型同尺寸同圆角）
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24          // 静止态略小（原 26）；放大后仍是原来的观感尺寸
                        radius: 7
                        color: navItem.meta.soft
                        // 图标：两段（悬停一档 → 点选再一档），幅度只比文字略大一点，
                        // 免得图标吃掉全部的"放大感"；360ms + 极小过冲 = 顺而不僵
                        scale: navItem.selected ? 1.21 : (navItem.hovered ? 1.07 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 460
                                              easing.type: Easing.OutBack
                                              easing.overshoot: 1.06 }
                        }
                        CanvasIcon {
                            anchors.centerIn: parent
                            name: navItem.meta.icon
                            width: 14; height: 14
                            color: navItem.meta.deep
                        }
                    }
                    Text {           // 板块名：颜色 + 字重随选中变
                        anchors.verticalCenter: parent.verticalCenter
                        // 文字：两段，幅度提到几乎和图标同一量级（这样"字放大"才看得出来）；
                        // 360ms OutCubic 无过冲 —— 和图标只差一点回弹，层次还在但不抢戏
                        scale: navItem.selected ? 1.13 : (navItem.hovered ? 1.06 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 460; easing.type: Easing.OutCubic }
                        }
                        text: root.titles[index]
                        width: titleMeasure.implicitWidth      // 统一列宽（按最长标题）
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        font.family: Theme.fontFamily
                        // 只有**选中**才加粗；未选中用常规字重（原来写 Medium 会显得整体都偏粗）
                        font.weight: navItem.selected ? Font.DemiBold : Font.Normal
                        color: navItem.selected ? Theme.textPrimary : Theme.textSecondary
                        opacity: navItem.selected ? 1.0 : 0.75
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }

                MouseArea {
                    id: navMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(navItem.index)
                }
            }
        }
    }
}
