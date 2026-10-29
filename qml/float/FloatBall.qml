import QtQuick
import "../components"

// 课堂快捷悬浮球（测试版 · 独立窗口，不改主程序）
// ─────────────────────────────────────────────────────────────
// 球 →(点) **4 个气泡围着球转半圈弹出** →(点) 批量 / 抽取 / 设置
// 卡片：左上 ‹ 返回气泡层、右上角是「锁定位置」开关（绘制图标；默认不锁定=可直接拖动标题栏）
//
// 触摸优先：全程单指点击/拖动，不依赖 hover / 右键
//   · 点球=弹气泡；拖球=挪位置（>14px 才算拖）；长按 1.2 秒=退出确认
//   · 所有可点区域 ≥ 56px
//
// 毛玻璃：不用系统 Acrylic（会糊满整个矩形窗口，圆形会露方角）；
//   改为 Python 每 260ms 抓「窗口背后的桌面」→ 各元素 FrostedPanel 自行模糊 + 形状遮罩。
Window {
    id: win

    visible: true
    color: "transparent"
    // ⚠️ 不能用 Qt.Tool：那会让窗口变成 WS_POPUP，**系统 Acrylic 就不生效了**（实测渲染成纯白）。
    //    必须跟主程序一样带 Min/Max hint（OVERLAPPED 样式）。任务栏/ALT+TAB 里隐藏，
    //    由 Python 端补一个 WS_EX_TOOLWINDOW 扩展样式来做到。
    flags: Qt.Window | Qt.FramelessWindowHint
           | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint
           | Qt.WindowStaysOnTopHint
           | (floatNoActivateCtx ? Qt.WindowDoesNotAcceptFocus : 0)

    property bool floatNoActivate: true

    // ── 形态 ──
    property int mode: 0          // 0=球 1=气泡 2=批量 3=抽取 4=设置 5=退出确认
    readonly property bool isBall: mode === 0 || mode === 1
    readonly property bool isCard: mode >= 2

    // ── 窗口尺寸（每种形态的"安全区"见下面的 ballX/ballY 夹取）──
    // ⚠️ 球态和气泡态**用同一个窗口尺寸**：点球时窗口几何不变，
    //    否则系统窗口先动、QML 布局慢一帧 → 会看到一个"错位的球"闪一下。
    //    球态只显示中间那一块，其余靠窗口遮罩（Python 端 setMask）做成点击穿透。
    width: mode === 0 ? 240
         : mode === 1 ? 240
         : mode === 2 ? 470
         : mode === 3 ? 412
         : mode === 4 ? 412 : 320
    height: mode === 0 ? 310
          : mode === 1 ? 310
          : mode === 2 ? 430
          : mode === 3 ? 360
          : mode === 4 ? 208 : 156

    // ── 球在屏幕上的位置（唯一真源；窗口位置由它 + 形态偏移推出）──
    property real ballX: Math.max(140, Screen.width - 240)
    property real ballY: Math.max(150, Screen.height - 320)

    // 球在窗口内的偏移：球态=0；气泡态=(140,150)（球的左/上要留出气泡的位置）；卡片态=窗口右下
    readonly property real ballOffX: mode <= 1 ? 140 : width - 100
    readonly property real ballOffY: mode <= 1 ? 150 : height - 100

    // 窗口位置 = 球的位置 − 球在窗口内的偏移；再夹一次屏幕边界
    // （卡片比球大得多，靠近屏幕左/上边时靠这一步把整张卡拖回屏内）
    x: Math.round(Math.max(0, Math.min(ballX - ballOffX, Screen.width - width)))
    y: Math.round(Math.max(0, Math.min(ballY - ballOffY, Screen.height - height)))

    // ── 状态 ──
    property bool cardLocked: false       // 默认**不锁定**：点开小界面就能直接拖；点锁图标才钉住位置
    property int pickKind: 0              // 抽取对象：0=学生 1=小组
    property string cat: ""               // 操作分类（批量/抽取加分都要）
    property var selStudents: []          // 批量：勾选的学生 id
    property var picked: []               // 抽取结果
    property string flashMsg: ""
    property real holdP: 0

    readonly property bool dragging: ballMa.pressed && ballMa.moved

    // 供 Python 计算窗口遮罩/模糊区域。收回动画期间**保持气泡形状**，
    // 否则一关就切成"只有球"的遮罩 → 气泡被瞬间裁掉，看不到收回动画。
    property int maskMode: 0
    onModeChanged: {
        if (mode === 0) {
            win.maskMode = 1
            closeHold.restart()
        } else {
            win.maskMode = mode
            if (mode >= 2) win.cardLocked = false     // 每次打开小界面都从不锁定开始
            maskTimer.restart()
        }
    }
    Timer {
        id: closeHold
        interval: 400
        onTriggered: { win.maskMode = win.mode; win.maskVersion++ }
    }
    // 形态变了 → 让 Python 重算窗口遮罩（Acrylic 只糊遮罩范围内）
    Timer { id: maskTimer; interval: 0; onTriggered: win.maskVersion++ }
    property int maskVersion: 0
    // ⚠️ 由 Python 在 load **之前**用 context property 传入：窗口创建后再改 flags 会让 Qt 重建窗口，
    //    之前设好的窗口遮罩就丢了（表现为 Acrylic 又糊满整个矩形）。
    property bool floatNoActivateCtx: true

    // ══════════════════════════════════════════════════════════
    //  毛玻璃面（每个气泡自己一块）
    //  ⚠️ **不要把截图铺成窗口背景**：那样窗口的空隙会显示"滞后的桌面"，
    //     拖动/切换瞬间就露成一块方形残影、圆边还会和真实桌面对不上（看起来像边缘发锐）。
    //     这里把截图按元素位置裁出来、只放在元素内部（clip 裁剪盒），空隙保持真透明。
    // ══════════════════════════════════════════════════════════
    // 毛玻璃面：**模糊/圆角遮罩/白色 tint 全在 Python 端烘成一张 RGBA 图**，这里只贴图。
    // （系统 Acrylic / DwmEnableBlurBehindWindow 在这个悬浮窗里都不生效——最小复现里正常，
    //   但落地到这个窗口就不糊，原因未定位；抓屏又在 UI 线程外，所以走烘焙。）
    component Glass: Item {
        id: gs
        property real corner: width / 2
        property color tintColor: "#59ffffff"
        property bool soft: false        // true = 圆形 + 边缘向外渐隐（同悬浮球）
        property real fade: 0.26

        anchors.fill: parent

        // 硬边版（卡片用）
        Rectangle {
            anchors.fill: parent
            radius: gs.corner
            color: gs.tintColor
            visible: !gs.soft
        }
        // 渐隐版（气泡用）：径向渐变，中心保持原色、到圆周透明度归零
        Canvas {
            anchors.fill: parent
            visible: gs.soft
            property color face: gs.tintColor
            property real fd: gs.fade
            onFaceChanged: requestPaint()
            onFdChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                if (width < 4) return
                var r = Math.min(width, height) / 2
                var f = Math.round(face.r * 255) + "," + Math.round(face.g * 255) + ","
                        + Math.round(face.b * 255)
                var g = c.createRadialGradient(width / 2, height / 2, r * (1 - fd),
                                               width / 2, height / 2, r)
                g.addColorStop(0, "rgba(" + f + "," + face.a + ")")
                g.addColorStop(1, "rgba(" + f + ",0)")
                c.fillStyle = g
                c.fillRect(0, 0, width, height)
            }
        }
    }

    // 单色矢量图标：emoji 是彩色位图、没法改色，所以按同样的图形语义画成线稿。
    // kind: bolt(闪电) / screen(显示器) / people(两人) / dice(骰子) / gear(齿轮)
    component FloatIcon: Canvas {
        id: fi
        property string kind: "bolt"
        property color ink: "#ffffff"
        property real weight: 2.0
        width: 24; height: 24
        antialiasing: true
        onInkChanged: requestPaint()
        onKindChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var c = getContext("2d")
            c.reset()
            if (width < 4) return
            var k = width / 24
            c.scale(k, k)
            c.strokeStyle = String(Qt.rgba(fi.ink.r, fi.ink.g, fi.ink.b, fi.ink.a))
            c.fillStyle = c.strokeStyle
            c.lineWidth = fi.weight
            c.lineCap = "round"
            c.lineJoin = "round"

            if (fi.kind === "bolt") {
                c.beginPath()
                c.moveTo(13.5, 2.5); c.lineTo(6.5, 13.5); c.lineTo(11, 13.5)
                c.lineTo(10, 21.5); c.lineTo(17.5, 10.5); c.lineTo(12.6, 10.5)
                c.closePath(); c.stroke()
            } else if (fi.kind === "screen") {
                c.beginPath(); fi.rrect(c, 2.8, 4, 18.4, 12.4, 2); c.stroke()
                c.beginPath(); c.moveTo(12, 16.4); c.lineTo(12, 19.4); c.stroke()
                c.beginPath(); c.moveTo(8.2, 19.6); c.lineTo(15.8, 19.6); c.stroke()
            } else if (fi.kind === "people") {
                c.beginPath(); c.arc(8.6, 8.6, 3.1, 0, Math.PI * 2); c.stroke()
                c.beginPath(); c.moveTo(3.4, 19.4)
                c.quadraticCurveTo(4.6, 13.6, 8.6, 13.6)
                c.quadraticCurveTo(12.6, 13.6, 13.8, 19.4); c.stroke()
                c.beginPath(); c.arc(16.4, 10.2, 2.5, 0, Math.PI * 2); c.stroke()
                c.beginPath(); c.moveTo(15.4, 14.4)
                c.quadraticCurveTo(20.2, 14.6, 20.8, 19.4); c.stroke()
            } else if (fi.kind === "dice") {
                c.beginPath(); fi.rrect(c, 3.2, 3.2, 17.6, 17.6, 4.2); c.stroke()
                var pips = [[8.2, 8.2], [15.8, 8.2], [12, 12], [8.2, 15.8], [15.8, 15.8]]
                for (var i = 0; i < pips.length; i++) {
                    c.beginPath(); c.arc(pips[i][0], pips[i][1], 1.5, 0, Math.PI * 2); c.fill()
                }
            } else {   // gear：实心齿轮盘（8 颗梯形齿，有厚度）+ 中心挖孔，不是几根线
                var teeth = 8, rOut = 10.2, rRoot = 7.4, rHole = 3.2
                var tw = 0.105 * Math.PI                 // 齿的半角
                c.beginPath()
                for (var i = 0; i < teeth; i++) {
                    var base = i * (Math.PI * 2 / teeth)
                    var pts = [[base - tw, rRoot], [base - tw * 0.58, rOut],
                               [base + tw * 0.58, rOut], [base + tw, rRoot]]
                    for (var k = 0; k < 4; k++) {
                        var a2 = pts[k][0], rr = pts[k][1]
                        var px = 12 + rr * Math.cos(a2), py = 12 + rr * Math.sin(a2)
                        if (i === 0 && k === 0) c.moveTo(px, py)
                        else c.lineTo(px, py)
                    }
                }
                c.closePath()
                c.fill()
                // 中心孔：destination-out 把中间的圆挖掉
                c.globalCompositeOperation = "destination-out"
                c.beginPath(); c.arc(12, 12, rHole, 0, Math.PI * 2); c.fill()
                c.globalCompositeOperation = "source-over"
            }
        }

        function rrect(c, x, y, w, h, r) {
            c.moveTo(x + r, y)
            c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r)
            c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r)
            c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y)
            c.closePath()
        }
    }

    // ══════════════════════════════════════════════════════════
    //  球
    // ══════════════════════════════════════════════════════════
    Item {
        id: ballItem
        width: 100; height: 100
        x: win.ballOffX                    // 球在窗口内的位置
        y: win.ballOffY
        visible: win.isBall

        // 白色压到 62%：再厚就把下面的模糊盖没了，看着只是"白色半透明"
        // 底色 = 应用 logo 那套「蓝色混色」（marine），半透明；中间白色四芒星
        IridescentFill {
            anchors.fill: parent
            circle: true            // 真圆
            fade: 0.26              // 边缘向外渐隐（占半径 26%）
            scheme: "marine"
            opacity: 0.62           // 半透明（0.55 再收一点回来）
        }
        CanvasIcon {
            anchors.centerIn: parent
            name: "sparkle"
            width: 54; height: 54
            color: "#ffffff"
            // 点击时四芒星 q 弹放大再回落（OutBack 过冲，动效明显）
            scale: ballMa.pressed ? 1.24 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            }
        }

        // 长按进度环
        Canvas {
            anchors.fill: parent
            property real p: win.holdP
            visible: p > 0.01
            onPChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                var cx = width / 2, cy = height / 2, r = width / 2 - 8
                var a0 = -Math.PI / 2, a1 = -Math.PI / 2 + p * Math.PI * 2
                c.lineCap = "round"
                // 由内到外叠 4 层：芯亮、外圈淡 → 边缘自然渐隐（Canvas 没有模糊）
                var layers = [[3.0, 0.95], [7.0, 0.42], [12.0, 0.20], [18.0, 0.09]]
                for (var i = 0; i < layers.length; i++) {
                    c.strokeStyle = "rgba(255,255,255," + layers[i][1] + ")"
                    c.lineWidth = layers[i][0]
                    c.beginPath()
                    c.arc(cx, cy, r, a0, a1)
                    c.stroke()
                }
            }
        }

        Timer { id: holdTimer; interval: 1200; onTriggered: { win.holdP = 0; ballMa.held = true; win.mode = 5 } }
        NumberAnimation { id: holdRing; target: win; property: "holdP"; from: 0; to: 1; duration: 1200 }

        MouseArea {
            id: ballMa
            anchors.fill: parent
            property point grab: Qt.point(0, 0)
            property real bx0: 0
            property real by0: 0
            property bool moved: false
            property bool held: false      // 长按已触发 → 松手时不要再切气泡层

            onPressed: function(m) {
                grab = Qt.point(win.x + m.x, win.y + m.y)
                bx0 = win.ballX; by0 = win.ballY
                moved = false
                held = false
                holdRing.restart(); holdTimer.restart()
            }
            onPositionChanged: function(m) {
                var gx = win.x + m.x, gy = win.y + m.y
                // 阈值 14px：手指点按会抖几像素，8px 会把点击误判成拖动
                if (!moved && Math.abs(gx - grab.x) + Math.abs(gy - grab.y) <= 14) return
                if (!moved) { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }
                moved = true
                // 夹在安全区里：保证四种形态的窗口都能完整落在屏幕内
                win.ballX = Math.max(140, Math.min(bx0 + (gx - grab.x), Screen.width - 100))
                win.ballY = Math.max(150, Math.min(by0 + (gy - grab.y), Screen.height - 160))
            }
            onReleased: {
                holdRing.stop(); holdTimer.stop(); win.holdP = 0
                if (moved || held) return          // 拖动 / 长按都不当作"点一下"
                win.mode = (win.mode === 1) ? 0 : 1
            }
            onCanceled: { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }
        }
    }

    // ══════════════════════════════════════════════════════════
    //  1 · 四个气泡：围着球的上半圈（上 → 左上 → 左 → 左下）
    // ══════════════════════════════════════════════════════════
    Item {
        id: menuLayer
        anchors.fill: parent
        // 收回时必须继续可见到动画播完（否则会"啪"地消失）
        visible: win.mode === 1 || closeHold.running

        property real t: win.mode === 1 ? 1 : 0
        Behavior on t {
            NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
        }

        Repeater {
            // 相对**球心**的偏移。R=105、气泡 68px：
            //   离球边 21px（贴着）、相邻中心距 80px（间隔 12px）
            // 84px 的旧气泡在半个圆内排不下四个，所以缩到 68px。
            // 弹出顺序 = 数组顺序：软件主界面 → 批量选择 → 随机抽取 → 设置
            // 位置沿球边从"上"顺时针扫到"左下"，读起来是一条自然的弧
            model: [
                { k: "screen", m: -1, ox:    0, oy: -105 },   // ① 上：软件主界面
                { k: "people", m: 2,  ox:  -74, oy:  -74 },   // ② 左上：批量选择
                { k: "dice",   m: 3,  ox: -105, oy:    0 },   // ③ 左：随机抽取
                { k: "gear",   m: 4,  ox:  -74, oy:   74 }     // ④ 左下：设置
            ]
            delegate: Item {
                id: bub
                // 打开：按 index 依次；收回：反过来（后出来的先消失）
                readonly property int seq: (win.mode === 1) ? index : (3 - index)
                readonly property real p: Math.max(0, Math.min(1, (menuLayer.t - seq * 0.12) / 0.64))
                readonly property real cx: win.ballOffX + 50
                readonly property real cy: win.ballOffY + 50

                width: 68; height: 68
                // 位置**固定**（窗口遮罩按这些圆心算，Acyrlic 只糊这些圆）。
                // 弹出全靠 0.55→1 的缩放 + 淡入：不超出自家的遮罩圆，也就不会被裁。
                x: cx + modelData.ox - width / 2
                y: cy + modelData.oy - height / 2
                // 从很小放大到原尺寸（不是从半透明淡入）
                scale: 0.06 + 0.94 * p
                opacity: Math.min(1, p * 1.6)

                // 悬停时「气泡 + 图标」整组等比放大（OutBack = q 弹），移开自动复原。
                // ⚠️ 缩放放在内层 Item 上：MouseArea 仍按原尺寸接收事件，不会因放大缩小而反复进出。
                Item {
                    anchors.fill: parent
                    scale: bma.containsMouse ? 1.12 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.9 }
                    }
                    // 白色别太厚：70% 白会把下面那层模糊盖得看不见（只剩"白色半透明"）
                    Glass { soft: true; tintColor: bma.pressed ? "#8c000000" : "#52000000" }
                    FloatIcon {
                        kind: modelData.k
                        width: 26; height: 26
                        weight: 2.2
                        anchors.centerIn: parent
                    }
                }
                MouseArea {
                    id: bma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (modelData.m < 0) { win.flashMsg = "完整界面：合并后接上"; flashTimer.restart() }
                        else win.mode = modelData.m
                    }
                }
            }
        }

        FlashLine {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.top: parent.top; anchors.topMargin: 10
        }
    }

    // ══════════════════════════════════════════════════════════
    //  卡片共用玻璃底
    // ══════════════════════════════════════════════════════════
    Glass { visible: win.isCard; corner: 16; tintColor: "#6b000000" }

    // ══════════════════════════════════════════════════════════
    //  2 · 批量：50 人网格，按人加分
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 2

        CardHead { title: "批量加分" }   // 已选人数看标题栏右上的全选开关与高亮格即可（长标题会和开关重叠）

        Grid {
            id: stuGrid
            anchors.top: parent.top; anchors.topMargin: 70
            anchors.left: parent.left; anchors.leftMargin: 20
            columns: 10
            spacing: 6
            Repeater {
                model: reward.students
                delegate: Rectangle {
                    id: sc
                    readonly property bool on: win.selStudents.indexOf(modelData.id) >= 0
                    width: 38; height: 38; radius: 12
                    color: sc.on ? "#b3ffffff" : (scma.pressed ? "#33ffffff" : "#1affffff")
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name.length > 3 ? modelData.name.slice(0, 3) : modelData.name
                        color: sc.on ? "#1f2937" : "#ffffff"
                        font.pixelSize: 11
                        font.bold: sc.on
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: scma
                        anchors.fill: parent
                        onClicked: {
                            var a = win.selStudents.slice()
                            var i = a.indexOf(modelData.id)
                            if (i >= 0) a.splice(i, 1); else a.push(modelData.id)
                            win.selStudents = a
                        }
                    }
                }
            }
        }

        // 维度选择：放在界面**最下方并居中**（原来的「全选」胶囊已改为标题栏里的开关）
        Row {
            id: catRow
            anchors.bottom: parent.bottom; anchors.bottomMargin: 84
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: reward.categories
                delegate: Rectangle {
                    readonly property bool on: win.cat === modelData
                    height: 40
                    width: lbl2.implicitWidth + 24
                    radius: height / 2
                    color: on ? "#b3ffffff" : (cm.pressed ? "#33ffffff" : "#1affffff")
                    Text {
                        id: lbl2
                        anchors.centerIn: parent
                        text: modelData
                        color: on ? "#1f2937" : "#ffffff"
                        font.pixelSize: 14
                        font.bold: on
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        onClicked: win.cat = (win.cat === modelData ? "" : modelData)
                    }
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Text {
                text: "分值"
                anchors.verticalCenter: parent.verticalCenter
                color: "#d9ffffff"; font.pixelSize: 17; font.family: Theme.fontFamily
            }
            PointsPill { id: pts; from: 1; to: 20; value: 2; anchors.verticalCenter: parent.verticalCenter }
            CuteButton {
                tone: "primary"; text: "加分"
                implicitWidth: 112; implicitHeight: 52; fontSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyStudents(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 112; implicitHeight: 52; fontSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyStudents(false)
            }
        }

        FlashLine {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 78
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ══════════════════════════════════════════════════════════
    //  3 · 抽取（学生 / 小组）
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 3

        CardHead { title: "随机抽取" }

        // 抽谁：学生 / 小组 —— 用主界面的分段 Tab 组件（主题色，不再自己画翠绿胶囊）
        SegmentedTabs {
            id: kindTabs
            anchors.top: parent.top; anchors.topMargin: 66
            anchors.horizontalCenter: parent.horizontalCenter
            labels: ["学生", "小组"]
            currentIndex: win.pickKind
            onActivated: function(i) { win.pickKind = i; win.picked = [] }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 26
            spacing: 2
            Repeater {
                model: win.picked
                delegate: Text {
                    text: modelData.name
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#ffffff"
                    font.pixelSize: win.picked.length > 1 ? 24 : 32
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }

        }

        // 底部（上）：抽 [N] 名/个 + 「抽取」
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 82
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Text {
                text: "抽"
                anchors.verticalCenter: parent.verticalCenter
                color: "#d9ffffff"; font.pixelSize: 16; font.family: Theme.fontFamily
            }
            PointsPill { id: pickCount; from: 1; to: 5; value: 1; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: win.pickKind === 0 ? "名学生" : "个小组"
                anchors.verticalCenter: parent.verticalCenter
                color: "#d9ffffff"; font.pixelSize: 16; font.family: Theme.fontFamily
            }
            CuteButton {
                tone: "primary"; text: "抽取"
                implicitWidth: 104; implicitHeight: 50; fontSize: 18
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.doPick()
            }
        }

        // 底部（下）：分值 + 加分 / 扣分（「再抽」已去掉）
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Text {
                text: "分值"
                anchors.verticalCenter: parent.verticalCenter
                color: "#d9ffffff"; font.pixelSize: 15; font.family: Theme.fontFamily
            }
            PointsPill { id: pickPts; from: 1; to: 20; value: 1; anchors.verticalCenter: parent.verticalCenter }
            CuteButton {
                tone: "primary"; text: "加分"
                implicitWidth: 104; implicitHeight: 52; fontSize: 19
                usable: win.picked.length > 0
                onClicked: win.applyPicked(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 104; implicitHeight: 52; fontSize: 19
                usable: win.picked.length > 0
                onClicked: win.applyPicked(false)
            }
        }

        FlashLine {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 74
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ══════════════════════════════════════════════════════════
    //  4 · 设置
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 4

        CardHead { title: "设置" }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 12
            spacing: 14
            CuteButton {
                tone: "danger"; text: "退出悬浮球"
                implicitWidth: 220; implicitHeight: 52; fontSize: 19
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: win.mode = 5
            }
            Text {
                text: "提示：长按球 1.2 秒也可以退出"
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#a6ffffff"; font.pixelSize: 15; font.family: Theme.fontFamily
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    //  5 · 退出确认
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 5

        Column {
            anchors.centerIn: parent
            spacing: 20
            Text {
                text: "退出悬浮球？"
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#ffffff"
                font.pixelSize: 20; font.bold: true; font.family: Theme.fontFamily
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                CuteButton {
                    tone: "secondary"; text: "取消"
                    implicitWidth: 124; implicitHeight: 54; fontSize: 19
                    onClicked: win.mode = 0
                }
                CuteButton {
                    tone: "danger"; text: "退出"
                    implicitWidth: 124; implicitHeight: 54; fontSize: 19
                    onClicked: Qt.quit()
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    Timer { id: flashTimer; interval: 1600; onTriggered: win.flashMsg = "" }

    // ══════════════════════════════════════════════════════════
    //  业务
    // ══════════════════════════════════════════════════════════
    function flash(t) { win.flashMsg = t; flashTimer.restart() }

    function applyStudents(isAdd) {
        if (!win.selStudents.length) { flash("请先点选学生"); return }
        if (!win.cat) { flash("请先选操作分类"); return }
        var n = pts.value
        var msg = reward.batchPointChange(win.selStudents.join(','), n, isAdd, win.cat)
        flash(msg ? msg : ((isAdd ? "＋" : "－") + n + " 分 · " + win.selStudents.length + " 人"))
    }

    function doPick() {
        var raw = win.pickKind === 0
                ? reward.randomPickStudents(pickCount.value)
                : reward.randomPickGroups(pickCount.value)
        var src = win.pickKind === 0 ? reward.students : reward.groups
        var out = []
        for (var i = 0; i < raw.length; i++) {
            for (var j = 0; j < src.length; j++) {
                if (src[j].id === raw[i].id) { out.push(src[j]); break }
            }
        }
        win.picked = out
    }

    function applyPicked(isAdd) {
        if (!win.picked.length) return
        var n = pickPts.value
        var names = []
        if (win.pickKind === 0) {
            if (!win.cat) { flash("请先在「批量」里选一次分类"); return }
            for (var i = 0; i < win.picked.length; i++) {
                reward.pointChange(win.picked[i].id, n, isAdd, win.cat)
                names.push(win.picked[i].name)
            }
        } else {
            for (var k = 0; k < win.picked.length; k++) {
                if (isAdd) reward.addGroupPoints(win.picked[k].id, n)
                else reward.subtractGroupPoints(win.picked[k].id, n)
                names.push(win.picked[k].name)
            }
        }
        flash((isAdd ? "＋" : "－") + n + " 分：" + names.join("、"))
    }

    // ══════════════════════════════════════════════════════════
    //  小部件
    // ══════════════════════════════════════════════════════════
    component CardHead: Item {
        property string title: ""
        anchors.top: parent.top; anchors.topMargin: 12
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: parent.right; anchors.rightMargin: 16
        height: 44

        // 拖动区（未锁定时可按标题栏拖窗口）。⚠️ 必须声明在按钮之前=在按钮下面，
        //    否则会把 ‹ 和「锁定」按钮的点击一起吃掉。
        MouseArea {
            anchors.fill: parent
            enabled: !win.cardLocked
            cursorShape: win.cardLocked ? Qt.ArrowCursor : Qt.SizeAllCursor
            property point grab: Qt.point(0, 0)
            property real bx0: 0
            property real by0: 0
            onPressed: function(m) {
                grab = Qt.point(win.x + m.x, win.y + m.y)
                bx0 = win.ballX; by0 = win.ballY
            }
            onPositionChanged: function(m) {
                var gx = win.x + m.x, gy = win.y + m.y
                win.ballX = Math.max(0, Math.min(bx0 + (gx - grab.x), Screen.width - win.width + win.ballOffX))
                win.ballY = Math.max(0, Math.min(by0 + (gy - grab.y), Screen.height - win.height + win.ballOffY))
            }
        }

        BackBtn { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
        // 批量页：全选开关（与主界面批量操作页同款 GlassSwitch），放在锁定按钮左边
        Row {
            visible: win.mode === 2
            anchors.right: parent.right
            anchors.rightMargin: 54
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: "全选"
                anchors.verticalCenter: parent.verticalCenter
                color: "#d9ffffff"; font.pixelSize: 13; font.family: Theme.fontFamily
            }
            GlassSwitch {
                id: allSwitch
                anchors.verticalCenter: parent.verticalCenter
                // ⚠️ 不用 checked: 绑定（点击会打断绑定），用 Connections 单向同步
                onToggled: {
                    var all = reward.students.map(function(st) { return st.id })
                    win.selStudents = checked ? all : []
                }
                Connections {
                    target: win
                    function onSelStudentsChanged() {
                        allSwitch.checked = reward.students.length > 0
                                             && win.selStudents.length === reward.students.length
                    }
                }
            }
        }
        LockBtn {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            visible: win.mode !== 4          // 设置页不需要锁定
        }
        Text {
            anchors.centerIn: parent
            text: parent.title
            color: "#ffffff"
            font.pixelSize: 19; font.bold: true; font.family: Theme.fontFamily
        }
    }

    component BackBtn: Rectangle {
        id: bb
        width: 44; height: 44; radius: 22
        color: bma.pressed ? "#40ffffff" : "#20ffffff"
        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 26; color: "#ffffff" }
        MouseArea { id: bma; anchors.fill: parent; onClicked: win.mode = 1 }
    }

    // 锁定开关：锁着=卡片固定在原地（防止误拖）；解锁=可按标题栏拖动
    component LockBtn: Rectangle {
        id: lb
        width: 44; height: 44; radius: 22
        // 只有「锁定时」才高亮，高亮 = 半透明白
        color: lma.pressed ? "#8cffffff" : (win.cardLocked ? "#59ffffff" : "transparent")
        // 绘制锁形：锁定 = 完整锁梁；解锁 = 锁梁开口
        Canvas {
            anchors.centerIn: parent
            width: 20; height: 20
            antialiasing: true
            property bool locked: win.cardLocked
            onLockedChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                var k = width / 24
                c.scale(k, k)
                c.strokeStyle = "#ffffff"
                c.fillStyle = "#ffffff"
                c.lineWidth = 2.2
                c.lineCap = "round"
                c.lineJoin = "round"
                // 锁体
                c.globalAlpha = 0.95
                c.beginPath()
                c.moveTo(6.6, 11.2); c.lineTo(17.4, 11.2)
                c.lineTo(17.4, 20.2); c.lineTo(6.6, 20.2)
                c.closePath(); c.fill()
                c.globalAlpha = 1
                // 锁梁
                c.beginPath()
                if (locked) {
                    c.moveTo(9, 11.2); c.lineTo(9, 7.8)
                    c.arc(12, 7.8, 3, Math.PI, 0, false)
                    c.lineTo(15, 11.2)
                } else {
                    c.moveTo(9, 11.2); c.lineTo(9, 7.8)
                    c.arc(12, 7.8, 3, Math.PI, Math.PI * 1.62, false)
                }
                c.stroke()
            }
        }
        MouseArea {
            id: lma
            anchors.fill: parent
            onClicked: {
                win.cardLocked = !win.cardLocked
                win.flash(win.cardLocked ? "已锁定位置" : "已解锁，可按标题栏拖动")
            }
        }
    }

    component FlashLine: Text {
        text: win.flashMsg
        visible: text !== ""
        color: "#6ee7d0"
        font.pixelSize: 15
        font.family: Theme.fontFamily
    }
}
