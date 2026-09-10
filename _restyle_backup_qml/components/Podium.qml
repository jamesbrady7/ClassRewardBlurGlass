import QtQuick

// 领奖台（纯展示）：暗场舞台 + 红色幕布（顶部帷幔 + 两侧束带侧帘，参考照片样式）
// + 顶部三盏射灯灯具（原标题位置）+ 三座金属台（顶面梯形与正面矩形一体绘制、严格共边）+ 暗红底座。
Item {
    id: root

    property var g1: null
    property var g2: null
    property var g3: null
    property int topGap: 48      // 台体上方留白带（面板顶到 Podium 顶）：放射灯灯具与幕布帷幔

    width: parent ? parent.width : 660
    height: 224

    readonly property int bw: 148
    readonly property int topDepth: 15
    readonly property int stageTopH: 16
    readonly property int stageFrontH: 24
    readonly property int stageBottomY: height - 12
    // 台子底边对齐底座正面顶边：stage.top + stageTopH
    readonly property int containerBottomY: (height - 12 - stageTopH - stageFrontH - 2) + stageTopH

    function blockH(rank) { return rank === 1 ? 122 : rank === 2 ? 84 : 52 }
    function blockTopY(r) { return root.containerBottomY - (blockH(r) + root.topDepth) }
    // —— 统一宽幅渐变（参照亚军的明暗跨度）——
    function fTop(r) { return r === 1 ? "#ffe296" : r === 2 ? "#eaf0f7" : "#f7c99e" }
    function fBot(r) { return r === 1 ? "#e69c22" : r === 2 ? "#b3c2d5" : "#cb7031" }
    function tCol(r) { return r === 1 ? "#ffcd5a" : r === 2 ? "#bfd0e2" : "#e5a06b" }
    function medal(r)  { return r === 1 ? "🥇" : r === 2 ? "🥈" : "🥉" }
    function plateBorder(r) { return r === 1 ? "#e8c166" : r === 2 ? "#9fb2c8" : "#dda072" }

    // ===== 红色幕布：帷幔+侧帘一体素材（幕布5.png 抠除棕色地板后的透明图）=====
    // 帘脚完整垂落并微微漫出面板底（~26px 被 clip）：布堆到地面的松弛感
    Image {
        id: curtainImg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -root.topGap
        height: root.topGap + root.height + 40
        fillMode: Image.Stretch
        smooth: true
        source: "../assets/curtain5.png"
    }


    // ===== 顶部三盏射灯（灯具在原标题所在的顶带，光锥照向各自台子）=====
    Canvas {
        id: lights
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -root.topGap
        height: root.topGap + root.height
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var topY = root.topGap
            var spots = [
                { x: cx - root.bw * 0.90, r: 2, a: 0.16, rx: 82 },
                { x: cx,                   r: 1, a: 0.30, rx: 92 },
                { x: cx + root.bw * 0.90,  r: 3, a: 0.16, rx: 82 }
            ]
            var lensY = 24
            // ⚠️ QtCanvas ellipse 只认 (x,y,w,h) 包围盒，一律按 bbox 画才居中
            function ell(cx, cy, rx, ry) { ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2) }
            for (var i = 0; i < spots.length; i++) {
                var s = spots[i]
                var landY = topY + root.blockTopY(s.r) + 8
                // —— 光锥：三层叠锥（外晕宽而淡 → 核心细而亮），边缘渐隐不生硬 ——
                var layers = [[1.05, 0.38], [0.74, 0.72], [0.45, 1.15]]
                for (var L = 0; L < 3; L++) {
                    var wf = layers[L][0], af = layers[L][1]
                    var a0 = Math.min(0.20, s.a * af)
                    var sw = 7 * wf, lw = s.rx * wf
                    var g = ctx.createLinearGradient(0, lensY + 2, 0, landY)
                    g.addColorStop(0.0, "rgba(255,244,218," + a0 + ")")
                    g.addColorStop(0.55, "rgba(255,244,218," + (a0 * 0.5) + ")")
                    g.addColorStop(1.0, "rgba(255,244,218,0)")
                    ctx.beginPath()
                    ctx.moveTo(s.x - sw, lensY + 2)
                    ctx.lineTo(s.x + sw, lensY + 2)
                    ctx.lineTo(s.x + lw, landY + 4)
                    ctx.lineTo(s.x - lw, landY + 4)
                    ctx.closePath()
                    ctx.fillStyle = g
                    ctx.fill()
                }
                // —— 落点光斑（收小收柔，只留一圈淡晕）——
                ctx.save()
                ctx.translate(s.x, landY + 3)
                ctx.scale(1, 0.3)
                var sp = ctx.createRadialGradient(0, 0, 0, 0, 0, s.rx * 0.7)
                sp.addColorStop(0.0, "rgba(255,238,200," + (s.a * 0.7) + ")")
                sp.addColorStop(1.0, "rgba(255,238,200,0)")
                ctx.beginPath()
                ctx.arc(0, 0, s.rx * 0.7, 0, Math.PI * 2)
                ctx.fillStyle = sp
                ctx.fill()
                ctx.restore()
                // —— 灯具 ——
                // 吸顶座 + 吊杆
                ctx.fillStyle = "#2a3140"
                ctx.fillRect(s.x - 12, 2.5, 24, 3.5)
                ctx.fillRect(s.x - 1.5, 5.5, 3, 3)
                // 筒身（更修长的金属渐变，与灯口同宽 20）
                var gb = ctx.createLinearGradient(0, 8, 0, 24)
                gb.addColorStop(0.0, "#3f4a59")
                gb.addColorStop(1.0, "#1e242e")
                ctx.fillStyle = gb
                ctx.fillRect(s.x - 10, 8, 20, 16)
                ctx.fillStyle = "rgba(255,255,255,0.10)"
                ctx.fillRect(s.x - 10, 8, 20, 2.5)
                // 两侧轭臂
                ctx.fillStyle = "#161b24"
                ctx.fillRect(s.x - 12, 10, 2, 10)
                ctx.fillRect(s.x + 10, 10, 2, 10)
                // 灯口（薄透镜与筒口齐平居中：细金圈 + 暖白镜片 + 一线白芯）
                ctx.beginPath()
                ell(s.x, lensY, 10, 2.8)
                var glens = ctx.createLinearGradient(0, lensY - 2.8, 0, lensY + 2.8)
                glens.addColorStop(0.0, "#fff7e2")
                glens.addColorStop(1.0, "#ffd98f")
                ctx.fillStyle = glens
                ctx.fill()
                ctx.strokeStyle = "#c9a24a"
                ctx.lineWidth = 1.3
                ctx.stroke()
                ctx.beginPath()
                ell(s.x, lensY - 0.6, 5.5, 1.5)
                ctx.fillStyle = "rgba(255,255,255,0.9)"
                ctx.fill()
                // 灯口辉光（收小收柔）
                var gl = ctx.createRadialGradient(s.x, lensY + 1, 0, s.x, lensY + 1, 16)
                gl.addColorStop(0.0, "rgba(255,246,220," + Math.min(0.42, s.a * 1.5) + ")")
                gl.addColorStop(1.0, "rgba(255,246,220,0)")
                ctx.beginPath()
                ctx.arc(s.x, lensY + 1, 16, 0, Math.PI * 2)
                ctx.fillStyle = gl
                ctx.fill()
            }
        }
        onWidthChanged: requestPaint()
    }

    // ===== 深色底座（顶面+正面一体绘制，对齐无缝）=====
    Rectangle {
        id: stage
        width: 3 * root.bw + 76
        height: root.stageTopH + root.stageFrontH + 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        color: "transparent"
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, hTop = root.stageTopH
                // 顶面（暗红舞台）：底边在 hTop，收口提亮成棱线
                var gt = ctx.createLinearGradient(0, 0, 0, hTop)
                gt.addColorStop(0.0, "#6e2020")
                gt.addColorStop(1.0, "#a03636")
                ctx.beginPath()
                ctx.moveTo(30, 0)
                ctx.lineTo(w - 30, 0)
                ctx.lineTo(w, hTop)
                ctx.lineTo(0, hTop)
                ctx.closePath()
                ctx.fillStyle = gt
                ctx.fill()
                // 正面：暗红，顶边比台面收口深一档
                var gf = ctx.createLinearGradient(0, hTop, 0, height)
                gf.addColorStop(0.0, "#8c2d2d")
                gf.addColorStop(1.0, "#4a1616")
                ctx.fillStyle = gf
                ctx.fillRect(0, hTop, w, height - hTop)
                // 底部暗线
                ctx.fillStyle = "#40000000"
                ctx.fillRect(0, height - 2, w, 2)
            }
            onWidthChanged: requestPaint()
        }
    }

    // ===== 三座台 =====
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: stage.top
        anchors.bottomMargin: -root.stageTopH
        height: root.blockH(1) + root.topDepth

        PodiumBlock { rank: 2; delay: 180; cx: root.width / 2 - root.bw * 0.90
            g: root.g2 }
        PodiumBlock { rank: 3; delay: 260; cx: root.width / 2 + root.bw * 0.90
            g: root.g3 }
        PodiumBlock { rank: 1; delay: 80;  cx: root.width / 2
            g: root.g1 }
    }

    // ===== 底座两端射灯（灯座 + 斜向光锥，掠过台面，画在最上层）=====
    Canvas {
        id: sideLights
        anchors.fill: parent
        z: 20
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var srcY = root.containerBottomY - 4
            var half = (3 * root.bw + 76) / 2
            var tgtY = root.blockTopY(1) + 26
            var lamps = [
                { sx: cx - half + 26, tx: cx - 60, dir: 1 },
                { sx: cx + half - 26, tx: cx + 60, dir: -1 }
            ]
            for (var i = 0; i < lamps.length; i++) {
                var L = lamps[i]
                var dx = L.tx - L.sx
                var dy = tgtY - srcY
                var len = Math.sqrt(dx * dx + dy * dy)
                var ang = Math.atan2(dy, dx)
                ctx.save()
                ctx.translate(L.sx, srcY)
                ctx.rotate(ang)
                // 光锥：双层叠锥（外晕 + 核心），掠过台面、收弱不刷白
                var passes = [[1.2, 0.045, 70], [0.5, 0.10, 56]]
                for (var P = 0; P < 2; P++) {
                    var pf = passes[P][0], pa = passes[P][1], ph = passes[P][2]
                    var g = ctx.createLinearGradient(0, 0, len, 0)
                    g.addColorStop(0.0, "rgba(255,240,206," + (pa * 1.5) + ")")
                    g.addColorStop(0.55, "rgba(255,240,206," + pa + ")")
                    g.addColorStop(1.0, "rgba(255,240,206,0)")
                    ctx.beginPath()
                    ctx.moveTo(0, -4 * pf)
                    ctx.lineTo(len, -ph * pf)
                    ctx.lineTo(len, ph * pf)
                    ctx.lineTo(0, 4 * pf)
                    ctx.closePath()
                    ctx.fillStyle = g
                    ctx.fill()
                }
                // 灯座（朝目标微倾的修长小筒灯 + 薄灯口）
                ctx.fillStyle = "#20262f"
                ctx.fillRect(-15, -6, 15, 12)
                ctx.fillStyle = "rgba(255,255,255,0.08)"
                ctx.fillRect(-15, -6, 15, 2)
                ctx.beginPath()
                ctx.ellipse(-2, -4, 4, 8)      // 灯口椭圆（bbox 法：左上角+宽高）
                ctx.fillStyle = "rgba(255,244,214,0.92)"
                ctx.fill()
                ctx.strokeStyle = "#c9a24a"
                ctx.lineWidth = 1.2
                ctx.stroke()
                ctx.restore()
                // 灯口辉光（小而柔）
                var gl = ctx.createRadialGradient(L.sx, srcY, 0, L.sx, srcY, 11)
                gl.addColorStop(0.0, "rgba(255,244,214,0.5)")
                gl.addColorStop(1.0, "rgba(255,244,214,0)")
                ctx.beginPath()
                ctx.arc(L.sx, srcY, 11, 0, Math.PI * 2)
                ctx.fillStyle = gl
                ctx.fill()
            }
        }
        onWidthChanged: requestPaint()
    }

    // 一座台：顶面+正面一体 Canvas（严格对齐），叠接触阴影/名牌/数字
    component PodiumBlock: Item {
        id: blk
        property int rank: 1
        property var g: null
        property real cx: 0
        property int delay: 100
        width: root.bw
        height: root.blockH(rank) + root.topDepth
        x: cx - width / 2
        anchors.bottom: parent.bottom
        opacity: 0

        // 一体块体（梯形底边 = 矩形顶边，严格共线）
        Canvas {
            id: bodyCv
            width: parent.width
            height: root.blockH(blk.rank) + root.topDepth
            anchors.bottom: parent.bottom
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width
                var faceTopY = root.topDepth
                // 顶面梯形：底边就在 faceTopY，收口提亮（与正面形成受光棱线）
                var gt = ctx.createLinearGradient(0, 0, 0, faceTopY)
                gt.addColorStop(0.0, Qt.darker(root.tCol(blk.rank), 1.12))
                gt.addColorStop(1.0, Qt.lighter(root.fTop(blk.rank), 1.12))
                ctx.beginPath()
                ctx.moveTo(13, 0)
                ctx.lineTo(w - 13, 0)
                ctx.lineTo(w, faceTopY)
                ctx.lineTo(0, faceTopY)
                ctx.closePath()
                ctx.fillStyle = gt
                ctx.fill()
                // 正面矩形：顶边从 faceTopY 起，起始比顶面收口深一档 → 棱线立体感
                var gf = ctx.createLinearGradient(0, faceTopY, 0, height)
                gf.addColorStop(0.0, Qt.darker(root.fTop(blk.rank), 1.07))
                gf.addColorStop(1.0, root.fBot(blk.rank))
                ctx.fillStyle = gf
                ctx.fillRect(0, faceTopY, w, height - faceTopY)
            }
            onWidthChanged: requestPaint()
        }
        // 与冠军台相接一侧的接触阴影（侧台才有）
        Rectangle {
            visible: blk.rank !== 1
            width: 30; height: root.blockH(blk.rank)
            anchors.top: bodyCv.top
            anchors.topMargin: root.topDepth
            anchors.left: blk.rank === 2 ? parent.right : undefined
            anchors.right: blk.rank === 3 ? parent.left : undefined
            anchors.leftMargin: blk.rank === 2 ? -width : 0
            anchors.rightMargin: blk.rank === 3 ? -width : 0
            z: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: blk.rank === 2 ? 0.0 : 1.0; color: "#00000000" }
                GradientStop { position: blk.rank === 2 ? 1.0 : 0.0; color: "#38000000" }
            }
        }

        // 雕刻名次「No.x」：刻痕色调跟随本台金属色（深一档刻体 + 亮一档槽光）
        property string noHtml: "No.<span style=\"font-size:" + (blk.rank === 1 ? 50 : 32)
                                + "px; font-weight:bold\">" + blk.rank + "</span>"
        property color engraveDark: Qt.darker(root.fBot(blk.rank), 1.55)
        property color engraveLight: Qt.lighter(root.fTop(blk.rank), 1.35)
        Text { // 下缘高光（槽壁反光，取本台提亮色）
            anchors.centerIn: bodyCv
            anchors.verticalCenterOffset: 9.5
            textFormat: Text.RichText
            text: blk.noHtml
            font.pixelSize: blk.rank === 1 ? 22 : 16
            font.bold: true
            font.family: Theme.fontFamily
            color: Qt.alpha(blk.engraveLight, 0.88)
        }
        Text { // 上缘暗影（槽口背光）
            anchors.centerIn: bodyCv
            anchors.verticalCenterOffset: 5.5
            textFormat: Text.RichText
            text: blk.noHtml
            font.pixelSize: blk.rank === 1 ? 22 : 16
            font.bold: true
            font.family: Theme.fontFamily
            color: Qt.alpha(blk.engraveDark, 0.35)
        }
        Text { // 主体：本台深色刻痕
            anchors.centerIn: bodyCv
            anchors.verticalCenterOffset: 7.5
            textFormat: Text.RichText
            text: blk.noHtml
            font.pixelSize: blk.rank === 1 ? 22 : 16
            font.bold: true
            font.family: Theme.fontFamily
            color: Qt.alpha(blk.engraveDark, 0.8)
        }

        // 铭牌（坐在台面上）
        Rectangle {
            width: Math.min(root.bw - 10, plateRow.implicitWidth + 22)
            height: 26
            radius: 7
            color: "#2d3846"
            border.color: root.plateBorder(blk.rank)
            border.width: 1.5
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: bodyCv.top
            anchors.bottomMargin: -6
            Row {
                id: plateRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: root.medal(blk.rank)
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: blk.g ? blk.g.name : "—"
                    color: "#f2f5f8"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: blk.g ? blk.g.points + " 分" : ""
                    color: "#f0cf8a"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        transform: Translate { id: tr; y: 30 }
        Component.onCompleted: rise.start()
        ParallelAnimation {
            id: rise
            PauseAnimation { duration: blk.delay }
            ParallelAnimation {
                NumberAnimation { target: tr; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.period: 0.5 }
                NumberAnimation { target: blk; property: "opacity"; to: 1; duration: 260 }
            }
        }
    }
}
