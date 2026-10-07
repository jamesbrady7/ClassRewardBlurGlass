import QtQuick

// 玻璃开关：白色圆球/胶囊旋钮 + 弹回动画（照搬原型 GlassSwitch.qml）
//   · 胶囊轮廓向内柔和渐隐内阴影（非硬描边）
//   · 旋钮去硬阴影；切换滑动时"圆→胶囊(高不变、只拉长)→圆"，不溢出容器
//   · 本应用无昼夜模式 → 去掉原型的 theme.nightT 插值，取白天端点值
Item {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 52
    implicitHeight: 30

    // 位移进度 0=左 1=右 —— 唯一动画源；形变从它派生 → 位移与形变天然同步，左右两个方向都顺滑
    property real pos: checked ? 1 : 0
    Behavior on pos { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    // 形变因子：行程中点为 1、两端为 0（自带"拉伸→恢复"，无需第二条动画；左滑右滑完全对称）
    readonly property real stretch: 4 * pos * (1 - pos)
    readonly property real knobW: 24 + stretch * 7

    // ── 配色 ──
    // 搭配原则（原型里定的）：**层次靠明度差、不靠彩度差**。
    //   填充 = 浅色 + 高灰度（低饱和），先把面"灰"下去；
    //   阴影 = 深色 + **保留高饱和**（"明度高一点的深色"，不压死）。
    // 阴影始终比填充更饱和（S 0.55 vs 0.33），但整体没有两团艳色打架。
    // ⚠️ 关态与开态**不能共用同一个明度**：同明度下饱和色看起来比灰更亮（明度错觉）。
    // ⚠️ 一律**实色**（alpha 恒 1）——那份"随主题适配"的职责由明度承担。
    readonly property real hueDeg: 160

    // ── 值关系（素描关系）──────────────────────────────
    // 填充 = 中间值   阴影 = 填充 − 0.16   反光 = 填充 + 0.18
    // 这套比例是从原型"夜间关态"（用户认为完美的那套）反推的（0.300 / 0.140 / 0.480），
    // 其余状态按同一差值推导 —— 别每种状态单独调，否则同样写着"有阴影有反光"却不是一套东西。
    // 「开度」0→1：checked 的平滑量
    property real onP: root.checked ? 1 : 0
    Behavior on onP { NumberAnimation { duration: 200 } }

    // 明度（白天端点值；原型这里还有一层 theme.nightT 在白天/夜间两端之间插值）
    readonly property real fillL: 0.720 + 0.010 * onP
    readonly property real shadeL: fillL - 0.16
    readonly property real glossL: fillL + 0.18

    // 饱和度：开态填充低饱和（先把面"灰"下去）、阴影保留高饱和（"透气"）；
    //         反光比填充再淡一点（光会褪色）；关态一律归零（只留明度差）
    readonly property real satFill: 0.33 * onP
    readonly property real satShade: 0.55 * onP
    readonly property real satGloss: 0.26 * onP

    property color trackColor: Qt.hsla(hueDeg / 360, satFill, fillL, 1)
    property color shadeColor: Qt.hsla(hueDeg / 360, satShade, shadeL, 1)
    property color glossColor: Qt.hsla(hueDeg / 360, satGloss, glossL, 1)

    function _rgbaStr(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
               + Math.round(c.b * 255) + "," + (a === undefined ? c.a.toFixed(3) : a) + ")"
    }

    // 轨道 + 内阴影 + 底部反光：都画在同一个 Canvas 里（三者同一坐标系，不用再对齐多个 item）
    Canvas {
        id: trackFx
        anchors.fill: parent
        // 轨道色随开度插值，得跟着重绘。
        // ⚠️ 处理器必须挂在属性所属对象上（trackColor 在 root 上），写在 Canvas 里会报
        //    "Cannot assign to non-existent property onTrackColorChanged"
        Connections {
            target: root
            function onTrackColorChanged() { trackFx.requestPaint() }
            function onShadeColorChanged() { trackFx.requestPaint() }
            function onGlossColorChanged() { trackFx.requestPaint() }
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height, r = h / 2
            ctx.beginPath()
            ctx.moveTo(r, 0)
            ctx.lineTo(w - r, 0); ctx.quadraticCurveTo(w, 0, w, r)
            ctx.lineTo(w, h - r); ctx.quadraticCurveTo(w, h, w - r, h)
            ctx.lineTo(r, h); ctx.quadraticCurveTo(0, h, 0, h - r)
            ctx.lineTo(0, r); ctx.quadraticCurveTo(0, 0, r, 0)
            ctx.closePath()
            // ① 轨道
            ctx.fillStyle = _rgbaStr(root.trackColor)
            ctx.fill()
            // ② 内阴影（只在上半部分，颜色随开关在"彩色/去色"间过渡）
            // ⚠️ 别想用 multiply 混合做"阴影比填充更饱和"：**本 Qt 的 Canvas 不支持混合模式**，
            //    会静默回退成普通覆盖，画上去的是乘数颜色本身（比填充色还亮），且不报错。
            //    可行做法：阴影色本身就是那块深绿、alpha=1 画在最深处，纯色而非"掺出来的灰"。
            //
            // 剖面刻意做成**曲线**而不是直线：贴着边缘那段最深最实、但只占很窄范围；
            // 往内迅速转虚、再拖出一条很长的尾巴。用多个 stop 把"衰减速度递减"雕出来：
            //   位置   0    0.10   0.20   0.40   0.60   0.82   1.00
            //   α      1    0.62   0.33   0.19   0.12   0.05   0
            //   段斜率 -3.80 -2.90  -0.70  -0.35  -0.32  -0.28   ← 斜率绝对值单调递减 = 先陡后缓
            ctx.clip()
            var sh = root.shadeColor
            function stop(p, a) { return _rgbaStr(sh, a) }
            var g = ctx.createLinearGradient(0, 0, 0, h * 0.5)
            g.addColorStop(0.00, stop(0, 1.00))
            g.addColorStop(0.10, stop(0, 0.62))
            g.addColorStop(0.20, stop(0, 0.33))
            g.addColorStop(0.40, stop(0, 0.19))
            g.addColorStop(0.60, stop(0, 0.12))
            g.addColorStop(0.82, stop(0, 0.05))
            g.addColorStop(1.00, stop(0, 0.00))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, w, h * 0.5)
            // 上端两个圆角处再收一点（径向四向自然衰减；
            // 横向线性渐变只按 x 衰减，会在 h/2 处切出一条横线）
            var g3 = ctx.createRadialGradient(0, 0, 0, 0, 0, w * 0.22)
            g3.addColorStop(0, _rgbaStr(sh, 0.92))
            g3.addColorStop(0.35, _rgbaStr(sh, 0.30))
            g3.addColorStop(1, _rgbaStr(sh, 0))
            ctx.fillStyle = g3
            ctx.fillRect(0, 0, w * 0.22, h * 0.5)
            var g4 = ctx.createRadialGradient(w, 0, 0, w, 0, w * 0.22)
            g4.addColorStop(0, _rgbaStr(sh, 0.92))
            g4.addColorStop(0.35, _rgbaStr(sh, 0.30))
            g4.addColorStop(1, _rgbaStr(sh, 0))
            ctx.fillStyle = g4
            ctx.fillRect(w - w * 0.22, 0, w * 0.22, h * 0.5)

            // ③ 底部反光高光（容器**内侧**底部）
            // 与②完全同一套逻辑，只是方向镜像（从 y=h 向上到中线）、颜色换成"同色相更亮"，
            // 峰值浓度也压低（高光在同样 alpha 下比阴影更抢眼）。物理上就是内凹面
            // 顶边落阴影、底边收对面折回来的反光——只做阴影那一半就会发平。
            ctx.clip()
            var gl = root.glossColor
            function gstop(a) { return _rgbaStr(gl, a) }
            var gb = ctx.createLinearGradient(0, h, 0, h * 0.5)
            gb.addColorStop(0.00, gstop(0.68))
            gb.addColorStop(0.10, gstop(0.42))
            gb.addColorStop(0.20, gstop(0.22))
            gb.addColorStop(0.40, gstop(0.12))
            gb.addColorStop(0.60, gstop(0.08))
            gb.addColorStop(0.82, gstop(0.035))
            gb.addColorStop(1.00, gstop(0.00))
            ctx.fillStyle = gb
            ctx.fillRect(0, h * 0.5, w, h * 0.5)
            // 下端两个圆角同样收一点（镜像上半那两颗）
            var g5 = ctx.createRadialGradient(0, h, 0, 0, h, w * 0.22)
            g5.addColorStop(0, _rgbaStr(gl, 0.60))
            g5.addColorStop(0.35, _rgbaStr(gl, 0.20))
            g5.addColorStop(1, _rgbaStr(gl, 0))
            ctx.fillStyle = g5
            ctx.fillRect(0, h * 0.5, w * 0.22, h * 0.5)
            var g6 = ctx.createRadialGradient(w, h, 0, w, h, w * 0.22)
            g6.addColorStop(0, _rgbaStr(gl, 0.60))
            g6.addColorStop(0.35, _rgbaStr(gl, 0.20))
            g6.addColorStop(1, _rgbaStr(gl, 0))
            ctx.fillStyle = g6
            ctx.fillRect(w - w * 0.22, h * 0.5, w * 0.22, h * 0.5)
        }
    }

    // 旋钮（白色；滑动时圆→胶囊→圆，高不变只拉长，不溢出容器）
    Rectangle {
        id: knob
        // x 完全由 pos 驱动（不依赖 width 的绑定），宽度的形变不会反过来干扰位移 → 两个方向都顺滑
        // pos=0 左边缘=3，pos=1 右边缘=parent.width-3；行程中即便拉长也始终在容器内
        y: (parent.height - 24) / 2
        width: root.knobW
        height: 24
        radius: height / 2
        color: "#ffffff"          // 原型的 theme.knobFace；本应用无昼夜，直接取白
        x: 3 + root.pos * (parent.width - 6 - width)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled()
        }
    }
}
