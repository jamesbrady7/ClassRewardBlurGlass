import QtQuick

// 圆形玻璃图标按钮：**照搬原型的 CircleButton**
//   次级 = 半透明白玻璃（悬停增亮）；accent = 多色杂糅渐变；无描边；柔光晕投影
//   raised = 立体极简：圆外"两个同尺寸的球"——白球偏左上露出、暗球偏右下露出，
//            中心实、外缘渐隐，再把圆内擦掉（按钮面保持平面）
// 本应用无昼夜模式，故去掉了原型的 nightT 插值（取原型的白天端点值）。
Item {
    id: root
    property string icon: ""
    property bool accent: false
    property string scheme: "mint"
    property real size: 42
    property bool shadow: true
    property bool raised: false
    readonly property bool hovered: ma.containsMouse
    readonly property bool pressed: ma.pressed
    signal clicked

    width: size; height: size
    implicitWidth: size; implicitHeight: size

    scale: pressed ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

    // 柔光晕投影
    SoftShadow {
        visible: root.shadow
        anchors.fill: parent
        anchors.margins: -14
        anchors.topMargin: -7
        anchors.bottomMargin: -7
        softColor: root.accent ? Qt.rgba(0.42, 0.40, 0.82, hovered ? 0.30 : 0.22)
                               : Qt.rgba(0.30, 0.33, 0.48, hovered ? 0.18 : 0.12)
    }

    // 立体（raised）：圆外光晕。白球左上、暗球右下，均从圆外向外发散；按钮面保持平面。
    Canvas {
        id: raisedFx
        visible: root.raised
        anchors.fill: parent
        // 边距按尺寸成比例：写死固定边距会把大按钮的渐变在画布边缘裁成方形
        anchors.margins: -root.size * 0.42
        property real coreRatio: 0.42          // 实心核占比：越大球体越成形、外缘渐隐越短
        function ball(ctx, w, h, ox, oy, outer, rgb, A) {
            var g = ctx.createRadialGradient(ox, oy, 0, ox, oy, outer)
            var N = 16
            var c = coreRatio
            for (var i = 0; i <= N; i++) {
                var t = i / N
                var u = Math.max(0, Math.min(1, (t - c) / (1 - c)))
                var s = u * u * (3 - 2 * u)    // smoothstep：无折点（分段线性会出现台阶）
                g.addColorStop(t, "rgba(" + rgb + "," + (A * (1 - s)).toFixed(4) + ")")
            }
            ctx.fillStyle = g
            ctx.fillRect(0, 0, w, h)
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var cx = w / 2, cy = h / 2
            var r = root.size / 2
            var off = root.size * 0.095            // 球向角部挪出多少（决定露出多少）
            var outer = r + root.size * 0.13       // 球的总半径（含外缘渐隐）
            ctx.save()
            ball(ctx, w, h, cx - off, cy - off, outer, "255,255,255", 0.72)
            ball(ctx, w, h, cx + off, cy + off, outer, "22,28,48", 0.24)
            // 只保留按钮外面的效果：把圆内的球擦掉
            // ⚠️ raisedSoftEdge 是**边缘那条过渡带的宽度**（占半径比例），要**小**：
            //    0 = 纯硬切；稍大只是把轮廓处的突变摊开一点点。
            //    （早先语义写成"过渡起点"取 0.12，等于 88% 半径都在渐变 → 圆内成了斜坡，很怪）
            ctx.globalCompositeOperation = "destination-out"
            var r0 = r * 0.93
            var m = ctx.createRadialGradient(cx, cy, r0, cx, cy, r)
            m.addColorStop(0, "rgba(0,0,0,1)")
            m.addColorStop(1, "rgba(0,0,0,0)")
            ctx.fillStyle = m
            ctx.fillRect(0, 0, w, h)
            ctx.globalCompositeOperation = "source-over"
            ctx.restore()
        }
    }

    // 次级玻璃面
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        opacity: root.accent ? 0 : 1
        color: hovered ? Theme.fillGlassHover : Theme.fillGlass
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // 彩色杂糅面
    IridescentFill {
        anchors.fill: parent
        rad: width / 2
        scheme: root.scheme
        opacity: root.accent ? 1 : 0
        hovered: root.hovered
        pressed: root.pressed
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    CanvasIcon {
        anchors.centerIn: parent
        name: root.icon
        width: root.size * 0.42; height: root.size * 0.42
        color: root.accent ? "#ffffff" : (hovered ? Theme.textPrimary : Theme.textSecondary)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
