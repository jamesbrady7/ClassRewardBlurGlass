import QtQuick
import "../components"

// 课堂快捷悬浮球（测试版 · 独立窗口，不改主程序）
// ─────────────────────────────────────────────────────────────
// 球 →(点) **4 个气泡围着球转半圈弹出** →(点) 倒计时 / 批量 / 抽取 / 退出软件
// 卡片：左上 ‹ 返回气泡层、右上角是「锁定位置」开关（绘制图标；默认不锁定=可直接拖动标题栏）
//
// 触摸优先：全程单指点击/拖动，不依赖 hover / 右键
//   · 点球=弹气泡；拖球=挪位置（>14px 才算拖）；长按 1.2 秒=直接回主界面
//   · 所有可点区域 ≥ 56px
//
// 毛玻璃：不用系统 Acrylic（会糊满整个矩形窗口，圆形会露方角）；
//   改为 Python 每 260ms 抓「窗口背后的桌面」→ 各元素 FrostedPanel 自行模糊 + 形状遮罩。
Window {
    id: win

    // ⚠️ 启动时必须不可见：这个窗口是在主窗口之后加载的，加载后再由 Python
    //    调 hide() 会留下一次"已映射、还没画"的空白窗口（340×340 黑块一闪）。
    //    进入悬浮球模式时由 FloatWindow._show_ball() 调 show() 显式打开；
    //    独立测试脚本加载后也要自己 show()。
    visible: false
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
    property int mode: 0          // 0=球 1=气泡 2=批量 3=抽取 5=退出确认 6=倒计时/秒表
    readonly property bool isBall: mode === 0 || mode === 1
    readonly property bool isCard: mode >= 2

    // ── 窗口尺寸（每种形态的"安全区"见下面的 ballX/ballY 夹取）──
    // ⚠️ 球态和气泡态**用同一个窗口尺寸**：点球时窗口几何不变，
    //    否则系统窗口先动、QML 布局慢一帧 → 会看到一个"错位的球"闪一下。
    //    球态只显示中间那一块，其余靠窗口遮罩（Python 端 setMask）做成点击穿透。
    // 卡片基准尺寸；显示尺寸 = 基准 × cardScale（用户拖右下角缩放）
    readonly property real cardBaseW: mode === 2 ? 470
                                    : mode === 3 ? 412
                                    : mode === 6 ? 412 : 260
    readonly property real cardBaseH: mode === 2 ? 430
                                    : mode === 3 ? 430
                                    : mode === 6 ? 400 : 132
    property real cardScale: 1.0
    Component.onCompleted: {
        if (typeof floatPrefs !== 'undefined' && floatPrefs)
            win.cardScale = floatPrefs.cardScale
    }
    // 拖拽过程中不停写盘会卡；停手 300ms 后存一次
    onCardScaleChanged: scaleSaveTimer.restart()
    Timer {
        id: scaleSaveTimer
        interval: 300
        onTriggered: {
            if (typeof floatPrefs !== 'undefined' && floatPrefs)
                floatPrefs.saveCardScale(win.cardScale)
        }
    }
    // 球/气泡态用 340×340 的方窗，球居中 → 气泡可以按球的屏幕位置往四个方向翻
    width: mode <= 1 ? 340 : cardBaseW * cardScale
    height: mode <= 1 ? 340 : cardBaseH * cardScale

    // ── 球在屏幕上的位置（唯一真源；窗口位置由它 + 形态偏移推出）──
    // 默认：屏幕右边、任务栏上沿（desktopAvailableHeight 已排除任务栏）
    property real ballX: Math.max(0, Screen.width - 100)
    property real ballY: Math.max(0, Screen.desktopAvailableHeight - 100)

    // 球在窗口内的偏移：球态/气泡态=(120,120)（340 方窗正中，气泡可向四边镜像）；
    // 卡片态=让卡片**中心落在球心上** → 小窗口就出现在球的位置，而不是从球往左上展开
    readonly property real ballOffX: mode <= 1 ? 120 : width / 2 - 50
    readonly property real ballOffY: mode <= 1 ? 120 : height / 2 - 50

    // 气泡弹出方向：只在球贴左/上边时镜像到右边/下边。
    // ⚠️ 右/下边不要再镜像——镜像会把整组推向更没空间的一侧（之前往下拖时
    //    气泡反而继续往下跑、越拖越看不见的根因）。
    readonly property int bubbleSignX: (ballX + 50 < 140) ? -1 : 1
    readonly property int bubbleSignY: (ballY + 50 < 140) ? -1 : 1
    onBubbleSignXChanged: win.maskVersion++
    onBubbleSignYChanged: win.maskVersion++

    // 四个气泡的图标固定顺序（从上到下）：计时器 → 批量 → 随机 → 关闭
    readonly property var bubbleIcons: [
        { k: "clock",  m: 6 },   // ① 计时器
        { k: "people", m: 2 },   // ② 批量选择
        { k: "dice",   m: 3 },   // ③ 随机抽选
        { k: "power",  m: 5 }    // ④ 关闭
    ]
    // 槽位几何保持现在这套围绕球的弧（相对球心）
    readonly property var bubbleSlots: [
        { ox:    0, oy: -105 },   // 槽 0：上
        { ox:  -74, oy:  -74 },   // 槽 1：左上
        { ox: -105, oy:    0 },   // 槽 2：左
        { ox:  -74, oy:   74 }    // 槽 3：左下
    ]
    // 按屏幕上的 y 从上到下排序槽位；图标固定按顺序装进排序后的槽
    // → 无论怎么镜像，屏幕上从上到下永远是 计时/批量/随机/关闭
    readonly property var bubbleSlotOrder: {
        var arr = []
        for (var i = 0; i < bubbleSlots.length; i++) arr.push(i)
        var sy = bubbleSignY
        arr.sort(function(a, b) {
            return bubbleSlots[a].oy * sy - bubbleSlots[b].oy * sy
        })
        return arr
    }

    // 窗口位置 = 球的位置 − 球在窗口内的偏移。
    // 球/气泡态**不夹屏幕边界**：球要能拖到任意边缘，窗口超出屏幕的部分由遮罩/透明区域处理；
    // 卡片态才夹回屏内（卡片内容必须完整可见）。
    x: mode <= 1 ? Math.round(ballX - ballOffX)
                 : Math.round(Math.max(0, Math.min(ballX - ballOffX, Screen.width - width)))
    y: mode <= 1 ? Math.round(ballY - ballOffY)
                 : Math.round(Math.max(0, Math.min(ballY - ballOffY, Screen.height - height)))

    // ── 状态 ──
    property bool cardLocked: false       // 默认**不锁定**：点开小界面就能直接拖；点锁图标才钉住位置
    property int pickKind: 0              // 抽取对象：0=学生 1=小组
    property string cat: ""               // 操作分类（批量/抽取加分都要）
    property var selStudents: []          // 批量：勾选的学生 id
    property var picked: []               // 抽取结果
    property string flashMsg: ""
    property bool flashIsError: false      // true → 提示用红色半透明胶囊
    property real holdP: 0

    // ── 倒计时 / 秒表 ──
    // 状态与逻辑都在共享的 TimerHub 里（主界面「工具箱」与悬浮球是**同一个实例**，
    // 由 main.py 注册成 context property "timerHub"）。这里只负责显示：
    // 关掉卡片后计时照走，球面上的进度环直接读 timerHub。
    // 计时按"结束时间戳"算，界面卡顿/后台都不会累积漂移。

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

    // 卡片 → 球/气泡：先把内容淡出，再改窗口尺寸。
    // 直接改 mode 时系统窗口先缩放、QML 慢一帧 → 会在新尺寸里看到旧卡片的残影。
    property bool leavingCard: false
    property int leaveTarget: 1
    function leaveCard(toMode) {
        if (win.mode <= 1 || win.leavingCard) return
        win.leaveTarget = toMode
        win.leavingCard = true
        cardLeave.start()
    }
    SequentialAnimation {
        id: cardLeave
        NumberAnimation { target: win.contentItem; property: "opacity"
                          to: 0; duration: 90; easing.type: Easing.InQuad }
        PauseAnimation { duration: 70 }        // 同理：透明帧先上屏，再缩窗口
        ScriptAction { script: win.mode = win.leaveTarget }
        PauseAnimation { duration: 50 }
        ScriptAction { script: win.contentItem.opacity = 1 }
        onFinished: win.leavingCard = false
    }

    // 气泡 → 卡片：先提前把遮罩切成"整窗"、把内容淡出，让窗口在不可见时完成
    // 缩放/移动，再淡入卡片。否则放大/移动的那一帧会被旧的小遮罩裁一下，
    // 闪出一块花屏状的残影。
    property bool enteringCard: false
    property int enterTarget: 2
    function enterCard(m) {
        if (win.enteringCard || win.leavingCard) return
        win.enterTarget = m
        win.enteringCard = true
        win.maskMode = m          // 提前切整窗遮罩（Python 会立即重算）
        win.maskVersion++
        cardEnter.start()
    }
    SequentialAnimation {
        id: cardEnter
        NumberAnimation { target: win.contentItem; property: "opacity"
                          to: 0; duration: 60; easing.type: Easing.InQuad }
        // ⚠️ 关键：等"全透明"那一帧真正上屏后再改窗口几何。
        //    否则窗口先移动/放大，合成器会把上一帧（球+气泡）连同旧位置一起带过去，
        //    在左上角闪一下残影。
        PauseAnimation { duration: 80 }
        ScriptAction { script: win.mode = win.enterTarget }
        PauseAnimation { duration: 50 }        // 等窗口尺寸/遮罩落定
        NumberAnimation { target: win.contentItem; property: "opacity"
                          to: 1; duration: 110; easing.type: Easing.OutQuad }
        onFinished: win.enteringCard = false
    }

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
    // kind: bolt(闪电) / screen(显示器) / people(两人) / dice(骰子) / clock(表) / power(电源)
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
            } else if (fi.kind === "clock") {
                // 表盘 + 表冠 + 两根指针（与其余图标同一套线稿笔触）
                c.beginPath(); c.arc(12, 13.0, 7.6, 0, Math.PI * 2); c.stroke()
                c.beginPath(); c.moveTo(12, 3.2); c.lineTo(12, 5.4); c.stroke()
                c.beginPath(); c.moveTo(9.9, 3.2); c.lineTo(14.1, 3.2); c.stroke()
                c.beginPath(); c.moveTo(12, 13.0); c.lineTo(12, 8.6); c.stroke()
                c.beginPath(); c.moveTo(12, 13.0); c.lineTo(15.3, 14.4); c.stroke()
                c.beginPath(); c.arc(12, 13.0, 0.9, 0, Math.PI * 2); c.fill()
            } else {   // power：电源符号（上端开口的圆环 + 中间竖线）
                c.beginPath()
                c.arc(12, 12.6, 7.6,
                      -Math.PI / 2 + 0.55,
                      -Math.PI / 2 - 0.55 + Math.PI * 2, false)
                c.stroke()
                c.beginPath(); c.moveTo(12, 2.8); c.lineTo(12, 11.8); c.stroke()
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
        // 倒计时进度环：画在球面内侧（半径 43 < 遮罩半径 52，不会被裁）
        // 走完 → 琥珀色 + 闪三下
        Canvas {
            id: cdRing
            anchors.centerIn: parent
            width: 96; height: 96
            visible: timerHub.timerRunning || timerHub.timerDone
                     || (timerHub.timerLeft > 0 && timerHub.timerLeft < timerHub.timerTotal)
            property real prog: timerHub.timerTotal > 0
                                ? timerHub.timerLeft / timerHub.timerTotal : 0
            property bool done: timerHub.timerDone
            onProgChanged: requestPaint()
            onDoneChanged: requestPaint()
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                var cx = width / 2, cy = height / 2, r = cx - 5
                c.lineWidth = 4
                c.lineCap = "round"
                c.strokeStyle = "rgba(255,255,255,0.18)"
                c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
                var p = cdRing.done ? 1 : Math.max(0, Math.min(1, cdRing.prog))
                c.strokeStyle = cdRing.done
                        ? "rgba(255,170,110,0.95)" : "rgba(120,232,210,0.95)"
                c.beginPath()
                c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p, false)
                c.stroke()
            }
        }
        SequentialAnimation {
            id: ringBlink
            loops: 3
            NumberAnimation { target: cdRing; property: "opacity"; to: 0.2; duration: 180 }
            NumberAnimation { target: cdRing; property: "opacity"; to: 1.0; duration: 220 }
        }
        // 点击涟漪：三圈白色细环从星芒开始依次扩散、淡出（水面涟漪）
        Canvas {
            id: sparkRipple
            anchors.centerIn: parent
            // 画布 240：星形几何一直画到 100px；屏幕显示由 82 的圆形遮罩裁掉尖尖
            width: 240; height: 240
            property real progress: 0
            onProgressChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                if (progress <= 0.001 || progress >= 0.999) return
                c.lineJoin = "round"
                c.lineCap = "round"
                var cx = width / 2, cy = height / 2
                // 用四芒星原路径当模板（24×24 坐标系里中心到顶点 = 8.4），按半径 s 缩放描边
                function starPath(cc, x, y, s) {
                    var u = s / 8.4
                    cc.beginPath()
                    cc.moveTo(x, y - 8.4 * u)
                    cc.quadraticCurveTo(x + 1 * u, y - 1 * u, x + 8.4 * u, y)
                    cc.quadraticCurveTo(x + 1 * u, y + 1 * u, x, y + 8.4 * u)
                    cc.quadraticCurveTo(x - 1 * u, y + 1 * u, x - 8.4 * u, y)
                    cc.quadraticCurveTo(x - 1 * u, y - 1 * u, x, y - 8.4 * u)
                    cc.closePath()
                }
                // [延迟, 单圈时长, 亮度系数, 最远半径, 扩散曲线指数, 淡出指数]
                // 前两圈冲得很远（100/96），由圆形遮罩把尖尖切掉；
                // 后两圈只到中途（62/48），在各自最远处淡出消失。
                var rings = [
                    [0.00, 0.78, 0.90, 100, 0.65, 0.40],
                    [0.24, 0.66, 0.72, 96, 0.58, 0.40],
                    [0.44, 0.54, 0.56, 62, 0.62, 1.50],
                    [0.60, 0.36, 0.33, 48, 0.60, 1.50]
                ]
                for (var i = 0; i < rings.length; i++) {
                    var d = rings[i][0], dur = rings[i][1], k = rings[i][2]
                    var rMax = rings[i][3], expo = rings[i][4], fade = rings[i][5]
                    var t = Math.max(0, Math.min(1, (progress - d) / dur))
                    if (t <= 0 || t >= 1) continue
                    // 各自的扩散曲线 → 有的头快尾慢、有的先慢后冲
                    var r = 2 + (rMax - 2) * Math.pow(t, expo)
                    // 远圈亮度一直保持到遮罩边（由 82 圆形遮罩切掉尖尖）；
                    // 中途圈淡出指数更大，会在半路自然消失
                    var a = 0.65 * Math.pow(1 - t, fade) * k
                    if (a <= 0.002) continue
                    starPath(c, cx, cy, r)
                    // 中间实、边缘虚：窄芯最亮，外面逐层变宽变淡
                    var layers = [[1.8, 0.95], [3.4, 0.55], [5.6, 0.30], [8.4, 0.14], [11.5, 0.05]]
                    // 极淡暗边：浅色桌面上也能看出星形轮廓
                    c.strokeStyle = "rgba(18,24,40," + (a * 0.12).toFixed(3) + ")"
                    c.lineWidth = 3.6
                    c.stroke()
                    for (var j = 0; j < layers.length; j++) {
                        c.strokeStyle = "rgba(255,255,255," + (a * layers[j][1]).toFixed(3) + ")"
                        c.lineWidth = layers[j][0]
                        c.stroke()
                    }
                }
                // 视觉遮罩（QML 内裁）：以球心为圆心的同心圆，半径 43——
                // 约 42px 以内是实的，42→43 极短渐隐，43 以外完全擦掉。
                // ⚠️ 窗口 setMask 只负责点击穿透/窗口区域，不能依赖它做视觉裁切。
                c.globalCompositeOperation = "destination-in"
                var mg = c.createRadialGradient(cx, cy, 0, cx, cy, 43)
                mg.addColorStop(0, "rgba(0,0,0,1)")
                mg.addColorStop(0.98, "rgba(0,0,0,1)")
                mg.addColorStop(1, "rgba(0,0,0,0)")
                c.fillStyle = mg
                c.fillRect(0, 0, width, height)
                c.globalCompositeOperation = "source-over"
            }
        }
        NumberAnimation {
            id: sparkRippleAnim
            target: sparkRipple
            property: "progress"
            from: 0; to: 1
            duration: 1400
            // 用线性进度，快慢差异交给每条涟漪自己的时长/指数
            easing.type: Easing.Linear
        }

        // 四芒星：外层负责"悬停呼吸"（上下 3px + 3% 缩放，3s 循环），
        // 内层负责"点击余波"（按下 120%，松手抖两下）。
        Item {
            id: sparkleWrap
            anchors.centerIn: parent
            width: 54; height: 54

            // 悬浮球的 MouseArea 盖在星芒上面，HoverHandler 收不到 hover；
            // 所以用球上的鼠标坐标判断"是否在星芒的 54×54 区域里"（球的中心 50,50）。
            property bool hovered: ballMa.sparkleHover
            property real breath: hovered ? 1 : 0
            property real phase: 0
            readonly property real wave: 0.5 - 0.5 * Math.cos(phase * Math.PI * 2)
            Behavior on breath { NumberAnimation { duration: 250; easing.type: Easing.InOutSine } }
            // ⚠️ 不能直接写 y：anchors.centerIn 会覆盖 y，位移必须用 Translate
            // 2026-10-31 用户要求：悬停时幅度再加大一点（3.6px / 3.5%），周期仍 3s
            scale: 1 + 0.035 * breath * wave
            transform: Translate { y: -3.6 * sparkleWrap.breath * sparkleWrap.wave }
            NumberAnimation on phase {
                running: sparkleWrap.hovered
                loops: Animation.Infinite
                from: 0; to: 1
                duration: 3000
            }

            Item {
                id: sparkClick
                anchors.fill: parent
                CanvasIcon {
                    anchors.centerIn: parent
                    name: "sparkle"
                    width: 54; height: 54
                    color: "#ffffff"
                }
            }
        }

        // 按下：120%（110ms）；松手：两次更明显的放大缩小（共 ~440ms）+ 涟漪扩散
        NumberAnimation {
            id: sparklePress
            target: sparkClick
            property: "scale"
            to: 1.20
            duration: 110
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            id: sparkleWobble
            // 三段递减的弹动（比原来多一段，更灵动）
            NumberAnimation { target: sparkClick; property: "scale"; to: 1.13; duration: 105; easing.type: Easing.InOutSine }
            NumberAnimation { target: sparkClick; property: "scale"; to: 0.92; duration: 115; easing.type: Easing.InOutSine }
            NumberAnimation { target: sparkClick; property: "scale"; to: 1.06; duration: 105; easing.type: Easing.InOutSine }
            NumberAnimation { target: sparkClick; property: "scale"; to: 0.97; duration: 95; easing.type: Easing.InOutSine }
            NumberAnimation { target: sparkClick; property: "scale"; to: 1.02; duration: 85; easing.type: Easing.InOutSine }
            NumberAnimation { target: sparkClick; property: "scale"; to: 1.00; duration: 75; easing.type: Easing.InOutSine }
        }
        NumberAnimation {
            id: sparkleSettle
            target: sparkClick
            property: "scale"
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }
        // 长按进度环：更细的弧线 + 更大的柔光（1.0→12px）
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
                // 更细的线 + 更大的柔光（1.0 → 12px）
                var N = 12
                for (var i = 0; i < N; i++) {
                    var u = i / (N - 1)
                    var w = 1.0 + 11.0 * u
                    var al = 0.95 * Math.pow(1 - u, 3.2)
                    c.strokeStyle = "rgba(255,255,255," + al.toFixed(3) + ")"
                    c.lineWidth = w
                    c.beginPath()
                    c.arc(cx, cy, r, a0, a1)
                    c.stroke()
                }
            }
        }
        // 进度前端的小四芒星：跟着弧线走，持续放大缩小 + 光晕闪烁
        Item {
            id: holdHead
            width: 24; height: 24
            visible: win.holdP > 0.01
            readonly property real ang: -Math.PI / 2 + win.holdP * Math.PI * 2
            x: 50 + Math.cos(ang) * 42 - width / 2
            y: 50 + Math.sin(ang) * 42 - height / 2
            property real pulse: 0
            scale: 0.85 + 0.3 * pulse
            SequentialAnimation on pulse {
                running: holdHead.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 420; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0; duration: 420; easing.type: Easing.InOutSine }
            }
            Canvas {
                anchors.centerIn: parent
                width: 30; height: 30
                // 光晕强度约为原来的 2.5 倍（面积 + 透明度都加大）
                opacity: 0.50 + 0.50 * holdHead.pulse
                onPaint: {
                    var c = getContext("2d"); c.reset()
                    var cx = width / 2, cy = height / 2, r = width / 2
                    var g = c.createRadialGradient(cx, cy, 0, cx, cy, r)
                    g.addColorStop(0, "rgba(255,255,255,0.9)")
                    g.addColorStop(0.45, "rgba(255,255,255,0.35)")
                    g.addColorStop(1, "rgba(255,255,255,0)")
                    c.fillStyle = g
                    c.fillRect(0, 0, width, height)
                }
            }
            CanvasIcon {
                anchors.centerIn: parent
                name: "sparkle"
                width: 14; height: 14
                color: "#ffffff"
            }
        }

        // 长按满 1.2 秒 = **直接回主界面**（进度环本身就是确认，不再弹确认卡）
        Timer {
            id: holdTimer
            interval: 1200
            onTriggered: {
                holdRing.stop()        // 先停进度动画，否则它会把 holdP 又推回 1
                win.holdP = 0
                ballMa.held = true
                // 留一帧把"干净的球"画出来再隐藏；否则下次出现会闪一下
                // 上次进度环读满时的旧画面
                holdReturn.start()
            }
        }
        Timer {
            id: holdReturn
            interval: 60
            onTriggered: floatBridge.closeBall()
        }
        NumberAnimation { id: holdRing; target: win; property: "holdP"; from: 0; to: 1; duration: 1200 }

        MouseArea {
            id: ballMa
            anchors.fill: parent
            hoverEnabled: true
            // 星芒的 54×54 区域（球 100×100 的正中）：用来做"悬停呼吸"
            readonly property bool sparkleHover: containsMouse
                    && mouseX >= 23 && mouseX <= 77
                    && mouseY >= 23 && mouseY <= 77
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
                sparkleWobble.stop(); sparkleSettle.stop()
                sparklePress.restart()
                sparkRippleAnim.restart()          // 一按下就开始涟漪（不等松手）
            }
            onPositionChanged: function(m) {
                if (!pressed) return       // 悬停移动只更新 sparkleHover，不拖动球
                var gx = win.x + m.x, gy = win.y + m.y
                // 阈值 14px：手指点按会抖几像素，8px 会把点击误判成拖动
                if (!moved && Math.abs(gx - grab.x) + Math.abs(gy - grab.y) <= 14) return
                if (!moved) { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }
                moved = true
                // 球可以贴到屏幕任意一边（窗口超出屏幕的部分由遮罩处理）；
                // 气泡会根据球的屏幕位置自动镜像到有空间的一侧
                win.ballX = Math.max(0, Math.min(bx0 + (gx - grab.x), Screen.width - 100))
                win.ballY = Math.max(0, Math.min(by0 + (gy - grab.y), Screen.height - 100))
            }
            onReleased: {
                holdRing.stop(); holdTimer.stop(); win.holdP = 0
                sparklePress.stop()
                if (moved || held) {               // 拖动 / 长按都不当作"点一下"
                    sparkleSettle.restart()
                    return
                }
                win.mode = (win.mode === 1) ? 0 : 1
                sparkleWobble.restart()            // 松手余波（涟漪已在按下时开始）
            }
            onCanceled: {
                holdRing.stop(); holdTimer.stop(); win.holdP = 0
                sparklePress.stop()
                sparkleSettle.restart()
            }
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
            // 图标按固定顺序（从上到下）；具体放到哪个槽由 bubbleSlotOrder 决定。
            // 槽位几何仍是现在这套围绕球的弧（R=105、气泡 68、贴球边 21px）。
            model: win.bubbleIcons
            delegate: Item {
                id: bub
                // 这个图标被分到哪个槽（按屏幕 y 从上到下排）
                readonly property var slot: win.bubbleSlots[win.bubbleSlotOrder[index]]
                // 打开：按 index 依次；收回：反过来（后出来的先消失）
                readonly property int seq: (win.mode === 1) ? index : (3 - index)
                readonly property real p: Math.max(0, Math.min(1, (menuLayer.t - seq * 0.12) / 0.64))
                readonly property real cx: win.ballOffX + 50
                readonly property real cy: win.ballOffY + 50

                width: 68; height: 68
                // 位置**固定**（窗口遮罩按这些圆心算，Acyrlic 只糊这些圆）。
                // 弹出全靠 0.55→1 的缩放 + 淡入：不超出自家的遮罩圆，也就不会被裁。
                x: cx + slot.ox * win.bubbleSignX - width / 2
                y: cy + slot.oy * win.bubbleSignY - height / 2
                // 从很小放大到原尺寸（不是从半透明淡入）
                scale: 0.06 + 0.94 * p
                opacity: Math.min(1, p * 1.6)

                // 悬停（方案 C）：气泡放大到 105% 并上浮 2px，图标稍晚放大到 110%；
                // 悬停期间整组再慢速呼吸（5% 缩放），柔光也更亮。
                // ⚠️ 缩放/位移放在内层 Item 上：MouseArea 仍按原尺寸接收事件，不会反复进出。
                Item {
                    id: bubBody
                    anchors.fill: parent
                    scale: bma.containsMouse ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 300; easing.type: Easing.InOutSine }
                    }
                    transform: Translate {
                        y: bma.containsMouse ? -2 : 0
                        Behavior on y {
                            NumberAnimation { duration: 300; easing.type: Easing.InOutSine }
                        }
                    }

                    // 悬停呼吸（和四芒星同一套做法：phase 循环 + breath 渐入）
                    property bool hovered: bma.containsMouse
                    property real breath: hovered ? 1 : 0
                    property real phase: 0
                    readonly property real wave: 0.5 - 0.5 * Math.cos(phase * Math.PI * 2)
                    Behavior on breath { NumberAnimation { duration: 250; easing.type: Easing.InOutSine } }
                    NumberAnimation on phase {
                        running: bubBody.hovered
                        loops: Animation.Infinite
                        from: 0; to: 1
                        duration: 2600
                    }

                    Item {
                        id: bubBreath
                        anchors.fill: parent
                        // 悬停呼吸：5%（原来 2.5% 太不明显）
                        scale: 1 + 0.05 * bubBody.breath * bubBody.wave

                        // 白色别太厚：70% 白会把下面那层模糊盖得看不见（只剩"白色半透明"）
                        Glass { soft: true; tintColor: bma.pressed ? "#8c000000" : "#52000000" }

                        // 柔光：只在悬停时淡入，半径收在气泡遮罩内
                        Canvas {
                            anchors.centerIn: parent
                            width: 68; height: 68
                            opacity: bma.containsMouse ? 0.30 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                var r = width / 2
                                var g = c.createRadialGradient(r, r, 0, r, r, r)
                                g.addColorStop(0, "rgba(255,255,255,0.9)")
                                g.addColorStop(0.5, "rgba(255,255,255,0.35)")
                                g.addColorStop(1, "rgba(255,255,255,0)")
                                c.fillStyle = g
                                c.fillRect(0, 0, width, height)
                            }
                        }

                        FloatIcon {
                            kind: modelData.k
                            width: 26; height: 26
                            weight: 2.2
                            anchors.centerIn: parent
                            // 图标比气泡多放一点，并晚 40ms 起步
                            scale: bma.containsMouse ? 1.10 : 1.0
                            Behavior on scale {
                                SequentialAnimation {
                                    PauseAnimation { duration: 40 }
                                    NumberAnimation { duration: 260; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: bma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: win.enterCard(modelData.m)
                }
            }
        }

        FlashLine {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.top: parent.top; anchors.topMargin: 10
        }
    }

    // ══════════════════════════════════════════════════════════
    //  卡片层：整层缩放（基准布局不动，窗口尺寸 = 基准 × cardScale）
    //  文字用全局曲线渲染，缩放后仍然清晰；右下角可拖拽缩放
    // ══════════════════════════════════════════════════════════
    Item {
        id: cardLayer
        width: win.cardBaseW
        height: win.cardBaseH
        scale: win.cardScale
        transformOrigin: Item.TopLeft
        visible: win.isCard

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
                    // 选中勾：右上角一个白色小圆圈 + 勾，微微外扩
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        visible: sc.on
                        color: Theme.accent
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -2
                        anchors.topMargin: -2
                        CanvasIcon {
                            anchors.centerIn: parent
                            name: "check"
                            width: 10; height: 10
                            strokeW: 4.8          // 24 网格坐标里的线宽；实际约 2px
                            color: "#ffffff"
                        }
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
                    readonly property bool hov: cm.containsMouse
                    height: 40
                    width: lbl2.implicitWidth + 24
                    radius: height / 2
                    color: on ? (hov ? "#d9ffffff" : "#b3ffffff")
                              : (cm.pressed ? "#40ffffff" : (hov ? "#33ffffff" : "#1affffff"))
                    Behavior on color {
                        ColorAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }
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
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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
                implicitWidth: 88; implicitHeight: 42; fontSize: 16
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyStudents(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 88; implicitHeight: 42; fontSize: 16
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyStudents(false)
            }
        }

        FlashLine {
            // 放到分类按钮上方（78 会压住分类胶囊；出错时最需要点的就是分类）
            anchors.bottom: parent.bottom; anchors.bottomMargin: 132
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
            anchors.verticalCenterOffset: -50
            spacing: 0
            Repeater {
                model: win.picked
                delegate: Text {
                    text: modelData.name
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#ffffff"
                    font.pixelSize: win.picked.length > 1 ? 20 : 32
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }

        }

        // 底部（上）：抽 [N] 名/个 + 「抽取」
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 152
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

        // 加分维度：与批量页同一套胶囊，选中后本页的加分/扣分直接使用
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 94
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: reward.categories
                delegate: Rectangle {
                    readonly property bool on: win.cat === modelData
                    readonly property bool hov: catMa.containsMouse
                    height: 40
                    width: catLbl.implicitWidth + 24
                    radius: height / 2
                    color: on ? (hov ? "#d9ffffff" : "#b3ffffff")
                              : (catMa.pressed ? "#40ffffff" : (hov ? "#33ffffff" : "#1affffff"))
                    Behavior on color {
                        ColorAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }
                    Text {
                        id: catLbl
                        anchors.centerIn: parent
                        text: modelData
                        color: on ? "#1f2937" : "#ffffff"
                        font.pixelSize: 14
                        font.bold: on
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: catMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.cat = (win.cat === modelData ? "" : modelData)
                    }
                }
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
                implicitWidth: 88; implicitHeight: 42; fontSize: 16
                usable: win.picked.length > 0
                onClicked: win.applyPicked(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 88; implicitHeight: 42; fontSize: 16
                usable: win.picked.length > 0
                onClicked: win.applyPicked(false)
            }
        }

        FlashLine {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 208
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ══════════════════════════════════════════════════════════
    //  6 · 倒计时
    //  卡片只负责"设置与显示"；计时器挂在根对象上，关掉卡片后继续走，
    //  球面上那圈进度环就是它在后台的指示。
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 6

        CardHead { title: timerHub.timerTab === 0 ? "倒计时" : "秒表" }

        // 倒计时 / 秒表：主界面同款分段 Tab（与抽取页的 学生/小组 一致）
        // 选中的子页也存在 TimerHub 里：在悬浮球选了「秒表」，回主界面工具箱也是「秒表」。
        SegmentedTabs {
            anchors.top: parent.top; anchors.topMargin: 60
            anchors.horizontalCenter: parent.horizontalCenter
            labels: ["倒计时", "秒表"]
            currentIndex: timerHub.timerTab
            onActivated: function(i) { timerHub.timerTab = i }
        }

        // ── 时 / 分 / 秒：每一位数字单独调（十位 0-6、个位 0-9 的轮盘）──
        Row {
            id: timePick
            visible: timerHub.timerTab === 0
            anchors.top: parent.top; anchors.topMargin: 100
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Repeater {
                model: [{ u: 0, label: "时" }, { u: 1, label: "分" }, { u: 2, label: "秒" }]
                delegate: Item {
                    id: unitCol
                    readonly property int unit: modelData.u
                    width: 80; height: 116

                    Row {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        DigitSpin {
                            digit: unitCol.unit === 0 ? timerHub.hT
                                   : unitCol.unit === 1 ? timerHub.mT : timerHub.sT
                            live: timerHub.timerIdle
                            onStepped: function(d) { timerHub.adjustDigit(unitCol.unit, 0, d) }
                        }
                        DigitSpin {
                            digit: unitCol.unit === 0 ? timerHub.hO
                                   : unitCol.unit === 1 ? timerHub.mO : timerHub.sO
                            live: timerHub.timerIdle
                            onStepped: function(d) { timerHub.adjustDigit(unitCol.unit, 1, d) }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 100
                        text: modelData.label
                        color: "#a6ffffff"
                        font.pixelSize: 12
                        font.family: Theme.fontFamily
                    }
                }
            }
        }

        Text {
            // 只在"暂停 / 时间到"时出现，平时不占视觉
            visible: timerHub.timerTab === 0
                     && (timerHub.timerDone
                         || (!timerHub.timerRunning && !timerHub.timerIdle))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: timePick.bottom; anchors.topMargin: 8
            text: timerHub.timerDone ? "时间到" : "已暂停"
            color: timerHub.timerDone ? "#ffc27a" : "#a6ffffff"
            font.pixelSize: 14
            font.family: Theme.fontFamily
        }

        Row {
            visible: timerHub.timerTab === 0
            anchors.bottom: parent.bottom; anchors.bottomMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            CuteButton {
                tone: "primary"
                text: timerHub.timerRunning ? "暂停"
                      : timerHub.timerDone ? "再来一次"
                      : (timerHub.timerLeft > 0 && timerHub.timerLeft < timerHub.timerTotal
                         ? "继续" : "开始")
                implicitWidth: 128; implicitHeight: 50; fontSize: 18
                usable: timerHub.timerTotal > 0      // 00:00:00 时不能开始
                onClicked: {
                    if (timerHub.timerRunning) timerHub.pauseTimer()
                    else timerHub.startTimer()
                }
            }
            CuteButton {
                tone: "secondary"; text: "重置"
                implicitWidth: 96; implicitHeight: 50; fontSize: 18
                onClicked: timerHub.resetTimer()
            }
        }

        // ── 秒表页 ──
        // 每按一次「计次」记录"距上一次"的用时（= 一组/一轮的时间），右边小字是累计。
        // 不同小组轮流比赛时：开始 → 每组完成按一下 → 列表里就是每组的成绩。
        Text {
            visible: timerHub.timerTab === 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 104
            text: timerHub.fmtSw(timerHub.swElapsed)
            color: "#ffffff"
            font.pixelSize: 50
            font.bold: true
            font.family: Theme.fontFamily
        }
        Row {
            visible: timerHub.timerTab === 1
            anchors.top: parent.top; anchors.topMargin: 168
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            CuteButton {
                tone: "primary"
                text: timerHub.swRunning ? "暂停"
                      : (timerHub.swElapsed > 0 ? "继续" : "开始")
                implicitWidth: 118; implicitHeight: 50; fontSize: 18
                onClicked: timerHub.swToggle()
            }
            CuteButton {
                tone: "secondary"; text: "计次"
                implicitWidth: 96; implicitHeight: 50; fontSize: 18
                usable: timerHub.swRunning || timerHub.swElapsed > 0
                onClicked: timerHub.swLap()
            }
            CuteButton {
                tone: "secondary"; text: "重置"
                implicitWidth: 82; implicitHeight: 50; fontSize: 18
                onClicked: timerHub.swReset()
            }
        }

        Flickable {
            id: splitView
            visible: timerHub.timerTab === 1
            anchors.top: parent.top; anchors.topMargin: 232
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true
            contentWidth: width
            contentHeight: splitCol.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Column {
                id: splitCol
                width: splitView.width
                spacing: 4
                Repeater {
                    model: timerHub.swSplits
                    delegate: Rectangle {
                        width: splitCol.width; height: 30; radius: 9
                        color: "#14ffffff"
                        Rectangle {
                            id: swBadge
                            width: 20; height: 20; radius: 10
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#33ffffff"
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: "#ffffff"
                                font.pixelSize: 11; font.bold: true
                                font.family: Theme.fontFamily
                            }
                        }
                        Text {
                            anchors.left: swBadge.right; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: timerHub.fmtSw(modelData.seg)
                            color: "#ffffff"
                            font.pixelSize: 15; font.bold: true
                            font.family: Theme.fontFamily
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "累计 " + timerHub.fmtSw(modelData.total)
                            color: "#80ffffff"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    //  5 · 退出软件确认
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 5

        Column {
            anchors.centerIn: parent
            spacing: 14
            Text {
                text: "退出软件？"
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#ffffff"
                font.pixelSize: 17; font.bold: true; font.family: Theme.fontFamily
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                CuteButton {
                    tone: "secondary"; text: "取消"
                    implicitWidth: 80; implicitHeight: 38; fontSize: 15
                    onClicked: win.leaveCard(0)
                }
                CuteButton {
                    tone: "danger"; text: "退出"
                    implicitWidth: 80; implicitHeight: 38; fontSize: 15
                    onClicked: floatBridge.quitApp()      // 确认后退出整个软件
                }
            }
        }
    }
    }   // cardLayer

    // 右下角缩放手柄：只在卡片态出现；拖动改 cardScale，双击复位
    Item {
        id: resizeGrip
        objectName: "resizeGrip"
        visible: win.isCard
        width: 24; height: 24
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        property real startScale: 1
        property real startGX: 0
        property real startGY: 0

        Canvas {
            anchors.fill: parent
            property bool hov: gma.containsMouse
            onHovChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset()
                c.strokeStyle = "rgba(255,255,255," + (hov ? 0.85 : 0.45) + ")"
                c.lineWidth = 1.6
                c.lineCap = "round"
                for (var i = 0; i < 3; i++) {
                    var o = 6 + i * 5
                    c.beginPath()
                    c.moveTo(width - o, height - 2)
                    c.lineTo(width - 2, height - o)
                    c.stroke()
                }
            }
        }
        MouseArea {
            id: gma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: function(m) {
                resizeGrip.startScale = win.cardScale
                resizeGrip.startGX = win.x + resizeGrip.x + m.x
                resizeGrip.startGY = win.y + resizeGrip.y + m.y
            }
            onPositionChanged: function(m) {
                if (!pressed) return
                var gx = win.x + resizeGrip.x + m.x
                var gy = win.y + resizeGrip.y + m.y
                var ns = resizeGrip.startScale
                       + (gx - resizeGrip.startGX) / win.cardBaseW
                       + (gy - resizeGrip.startGY) / win.cardBaseH
                win.cardScale = Math.max(0.8, Math.min(1.3, ns))
            }
            onDoubleClicked: win.cardScale = 1.0
        }
    }

    // ══════════════════════════════════════════════════════════
    Timer { id: flashTimer; interval: 1600; onTriggered: win.flashMsg = "" }

    // ══════════════════════════════════════════════════════════
    //  业务
    // ══════════════════════════════════════════════════════════
    function flash(t) { win.flashIsError = false; win.flashMsg = t; flashTimer.restart() }
    function flashError(t) { win.flashIsError = true; win.flashMsg = t; flashTimer.restart() }

    // 倒计时归零：球面进度环闪三下（计时状态本身在共享的 timerHub 里）
    Connections {
        target: timerHub
        function onCountdownFinished() { ringBlink.restart() }
    }

    function applyStudents(isAdd) {
        if (!win.selStudents.length) { flashError("请先点选学生"); return }
        if (!win.cat) { flashError("请先选操作分类"); return }
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
            if (!win.cat) { flashError("请先选操作分类"); return }
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
    // 单个数字轮：▲ / 数字 / ▼。时/分/秒各两个（十位、个位），每位独立调整。
    component DigitSpin: Item {
        id: ds
        property int digit: 0
        property bool live: true
        signal stepped(int delta)
        width: 30; height: 96

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            text: "▲"
            color: upHit.containsMouse && ds.live ? "#ffffff"
                   : ds.live ? "#b8ffffff" : "#40ffffff"
            font.pixelSize: 11
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: upHit
            anchors.horizontalCenter: parent.horizontalCenter
            y: -5; width: 30; height: 30
            hoverEnabled: true
            enabled: ds.live
            cursorShape: Qt.PointingHandCursor
            onClicked: ds.stepped(1)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 22
            text: String(ds.digit)
            color: timerHub.timerDone ? "#ffc27a" : (ds.live ? "#ffffff" : "#e6ffffff")
            font.pixelSize: 42
            font.bold: true
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 76
            text: "▼"
            color: downHit.containsMouse && ds.live ? "#ffffff"
                   : ds.live ? "#b8ffffff" : "#40ffffff"
            font.pixelSize: 11
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: downHit
            anchors.horizontalCenter: parent.horizontalCenter
            y: 71; width: 30; height: 28
            hoverEnabled: true
            enabled: ds.live
            cursorShape: Qt.PointingHandCursor
            onClicked: ds.stepped(-1)
        }
    }

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
                // 卡片层被缩放过，局部坐标要乘 cardScale 才是屏幕位移
                grab = Qt.point(win.x + m.x * win.cardScale, win.y + m.y * win.cardScale)
                bx0 = win.ballX; by0 = win.ballY
            }
            onPositionChanged: function(m) {
                var gx = win.x + m.x * win.cardScale
                var gy = win.y + m.y * win.cardScale
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
        color: bma.pressed ? "#59ffffff" : (bma.containsMouse ? "#3dffffff" : "#20ffffff")
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutQuad } }
        // 用 Canvas 画折线箭头：字体里的"‹"有侧边距，视觉上会偏一点；
        // 画出来的折线可以做到严格以圆心为中心
        Canvas {
            anchors.centerIn: parent
            width: 20; height: 20
            property color ink: bma.containsMouse ? "#ffffff" : "#f2ffffff"
            onInkChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset()
                c.strokeStyle = String(Qt.rgba(ink.r, ink.g, ink.b, ink.a))
                c.lineWidth = 2.2
                c.lineCap = "round"
                c.lineJoin = "round"
                c.beginPath()
                c.moveTo(12.85, 4.4)
                c.lineTo(7.15, 10)
                c.lineTo(12.85, 15.6)
                c.stroke()
            }
        }
        MouseArea {
            id: bma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.leaveCard(1)
        }
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
            onClicked: win.cardLocked = !win.cardLocked
        }
    }

    // 提示条：错误 = 红色半透明胶囊 + 白字；普通提示 = 半透明黑胶囊 + 薄荷字。
    // （批量没选分类时的提示就是红色胶囊，不再是孤零零一行字）
    component FlashLine: Rectangle {
        visible: win.flashMsg !== ""
        width: flashLabel.implicitWidth + 30
        height: 34
        radius: height / 2
        color: win.flashIsError ? "#66e06050" : "#66000000"

        Text {
            id: flashLabel
            anchors.centerIn: parent
            text: win.flashMsg
            color: win.flashIsError ? "#ffffff" : "#6ee7d0"
            font.pixelSize: 14
            font.family: Theme.fontFamily
        }
    }
}
