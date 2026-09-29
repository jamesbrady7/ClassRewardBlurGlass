import QtQuick

// 平铺的学生方块：**照搬原型 StudentsPage 的 StudentChip**
//   · 未选中 = 圆角方形玻璃面（悬停增亮）
//   · 选中   = 多色杂糅高亮面（原型用 mist 雾面冷白）+ 右上角薄荷绿对勾
//   · 形状用原型那条 quadraticCurveTo 圆角路径（rad = 宽/2），**不是** Rectangle 的 radius
//     —— 两者形状不同：前者是圆角方形、后者是正圆
Item {
    id: chip

    property string idText: ""          // 学号（本应用比原型多一行）
    property string label: ""           // 姓名
    property bool selected: false
    signal toggled

    readonly property bool hovered: ma.containsMouse

    // 「选中程度」0→1：**唯一**动画源 —— 填充透明度、文字颜色都从它取（避免两处各走各的）
    property real sel: selected ? 1 : 0
    Behavior on sel { NumberAnimation { duration: 130 } }

    function mixc(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    // 未选中的玻璃面（与彩色面**同一条圆角路径**）
    Canvas {
        id: face
        anchors.fill: parent
        visible: !chip.selected
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            var w = width, h = height, r = w / 2
            ctx.beginPath()
            ctx.moveTo(r, 0)
            ctx.lineTo(w - r, 0); ctx.quadraticCurveTo(w, 0, w, r)
            ctx.lineTo(w, h - r); ctx.quadraticCurveTo(w, h, w - r, h)
            ctx.lineTo(r, h); ctx.quadraticCurveTo(0, h, 0, h - r)
            ctx.lineTo(0, r); ctx.quadraticCurveTo(0, 0, r, 0)
            ctx.closePath()
            // ⚠️ 原型这里用 50%/74% 白，是因为它底下是较深/彩色的背板；本应用页面本身偏白，
            //    50% 白落在白卡上几乎看不见（实测只有压在彩色色块上的方块显形）。
            //    提高白度拉开与卡片的对比：静止 85%、悬停纯白
            ctx.fillStyle = chip.hovered ? "#ffffffff" : "#d9ffffff"
            ctx.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: chip
            function onHoveredChanged() { face.requestPaint() }
            function onSelectedChanged() { face.requestPaint() }
        }
    }

    // 选中的彩色高亮面（原型白天 mist / 夜间 aurora；本应用无昼夜 → 用 mist）
    IridescentFill {
        anchors.fill: parent
        rad: width / 2
        scheme: "mist"
        hovered: chip.hovered
        opacity: chip.sel
    }

    Column {
        anchors.centerIn: parent
        spacing: 1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: chip.idText
            // 字号随方块尺寸走（原型方块 42px，里面要放两行）
            font.pixelSize: Math.max(8, Math.round(chip.width * 0.22))
            font.family: Theme.fontFamily
            // 未选中=次要色；选中=mist 是浅色面 → 用深字（原型同规则），按 sel 平滑插值
            color: chip.mixc(Theme.textMuted, "#3f4660", chip.sel)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: chip.label
            font.pixelSize: Math.max(9, Math.round(chip.width * 0.27))
            font.family: Theme.fontFamily
            font.weight: chip.selected ? Font.DemiBold : Font.Normal
            color: chip.mixc(Theme.textPrimary, "#3f4660", chip.sel)
        }
    }

    // 打勾：薄荷绿圆底 + 白色对勾（压在右上角）
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.round(chip.width * 0.38); height: width
        radius: width / 2
        color: "#22bd8e"
        opacity: chip.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }
        CanvasIcon {
            anchors.centerIn: parent
            name: "check"
            width: Math.round(chip.width * 0.24); height: width
            color: "white"
        }
    }

    // 点击不做按压缩放：反馈就是"选中/取消"的高亮变化
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.toggled()
    }
}
