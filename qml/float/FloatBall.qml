import QtQuick
import "../components"

// 课堂快捷悬浮球（测试版 · 独立窗口，不改主程序）
// ─────────────────────────────────────────────────────────────
// 球 →(点) **4 个气泡围着球转半圈弹出** →(点) 批量 / 抽取 / 设置
// 卡片：左上 ‹ 回气泡层、右上 × 回球、右上角 🔒 锁定（锁定后不可拖动）
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
    property bool cardLocked: true        // 卡片默认锁定（防止误拖），点 🔒 解锁后可按标题栏拖动
    property int pickKind: 0              // 抽取对象：0=学生 1=小组
    property string cat: ""               // 操作分类（批量/抽取加分都要）
    property var selStudents: []          // 批量：勾选的学生 id
    property var picked: []               // 抽取结果
    property string flashMsg: ""
    property real holdP: 0

    readonly property bool dragging: ballMa.pressed && ballMa.moved

    onModeChanged: maskTimer.restart()
    // 形态变了 → 让 Python 重算窗口遮罩（Acrylic 只糊遮罩范围内）
    Timer { id: maskTimer; interval: 0; onTriggered: win.maskVersion++ }
    property int maskVersion: 0
    property int backdropVersion: 0     // 桌面截图版本（变了就换贴图）
    // ⚠️ 由 Python 在 load **之前**用 context property 传入：窗口创建后再改 flags 会让 Qt 重建窗口，
    //    之前设好的窗口遮罩就丢了（表现为 Acrylic 又糊满整个矩形）。
    property bool floatNoActivateCtx: true

    // ══════════════════════════════════════════════════════════
    //  毛玻璃面（每个气泡自己一块）
    //  ⚠️ **不要把截图铺成窗口背景**：那样窗口的空隙会显示"滞后的桌面"，
    //     拖动/切换瞬间就露成一块方形残影、圆边还会和真实桌面对不上（看起来像边缘发锐）。
    //     这里把截图按元素位置裁出来、只放在元素内部（clip 裁剪盒），空隙保持真透明。
    // ══════════════════════════════════════════════════════════
    // 毛玻璃面：**模糊 / 圆角遮罩 / 白色 tint 全在 Python 端烘成一张 RGBA 图**，这里只贴图。
    // （系统 Acrylic 在这个窗口上不认窗口遮罩 → 只能整矩形糊，圆形会露方角，所以不用它。）
    // 贴图 URL 带"元素在窗口内的位置"，切形态/拖动时由 Python 重新裁+烘。
    component Glass: Item {
        id: gs
        property real sx: 0
        property real sy: 0
        property real corner: width / 2
        property int tintA: 150
        anchors.fill: parent

        SoftShadow {
            anchors.fill: parent
            anchors.margins: -12
            softColor: "#3a1a2230"
        }
        Image {
            anchors.fill: parent
            cache: false
            smooth: true
            source: "image://floatglass/"
                    + Math.round(gs.sx) + "_" + Math.round(gs.sy) + "_"
                    + Math.round(width) + "_" + Math.round(height) + "_"
                    + Math.round(gs.corner) + "_" + gs.tintA
                    + "?v" + win.backdropVersion
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
        Glass { sx: win.ballOffX; sy: win.ballOffY; tintA: 150 }

        Text {
            anchors.centerIn: parent
            text: "⚡"
            font.pixelSize: 40
            scale: ballMa.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
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
                c.strokeStyle = "#0fa88f"
                c.lineWidth = 6
                c.lineCap = "round"
                c.beginPath()
                c.arc(width / 2, height / 2, width / 2 - 7,
                      -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2)
                c.stroke()
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
        visible: win.mode === 1

        property real t: win.mode === 1 ? 1 : 0
        Behavior on t {
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        Repeater {
            // 相对**球心**的偏移。R=105、气泡 68px：
            //   离球边 21px（贴着）、相邻中心距 80px（间隔 12px）
            // 84px 的旧气泡在半个圆内排不下四个，所以缩到 68px。
            model: [
                { g: "👥", m: 2,  ox:  -74, oy:   74 },   // 左下（离手最近）
                { g: "🎲", m: 3,  ox: -105, oy:    0 },   // 左
                { g: "🖥", m: -1, ox:  -74, oy:  -74 },   // 左上
                { g: "⚙", m: 4,  ox:    0, oy: -105 }    // 上
            ]
            delegate: Item {
                id: bub
                readonly property real p: Math.max(0, Math.min(1, (menuLayer.t - index * 0.10) / 0.70))
                readonly property real cx: win.ballOffX + 50
                readonly property real cy: win.ballOffY + 50

                width: 68; height: 68
                // 位置**固定**（窗口遮罩按这些圆心算，Acyrlic 只糊这些圆）。
                // 弹出全靠 0.55→1 的缩放 + 淡入：不超出自家的遮罩圆，也就不会被裁。
                x: cx + modelData.ox - width / 2
                y: cy + modelData.oy - height / 2
                scale: 0.55 + 0.45 * p
                opacity: p

                // 白色别太厚：70% 白会把下面那层模糊盖得看不见（只剩"白色半透明"）
                Glass { sx: bub.x; sy: bub.y; tintA: bma.pressed ? 215 : 118 }
                Text {
                    anchors.centerIn: parent
                    text: modelData.g
                    font.pixelSize: 26
                }
                MouseArea {
                    id: bma
                    anchors.fill: parent
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
    Glass { visible: win.isCard; sx: 0; sy: 0; corner: 22; tintA: 165 }

    // ══════════════════════════════════════════════════════════
    //  2 · 批量：50 人网格，按人加分
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 2

        CardHead { title: "批量加分 · 已选 " + win.selStudents.length + " 人" }

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
                    color: sc.on ? "#d90fa88f" : (scma.pressed ? "#4dffffff" : "#3dffffff")
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name.length > 3 ? modelData.name.slice(0, 3) : modelData.name
                        color: sc.on ? "#ffffff" : Theme.textPrimary
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

        Row {
            anchors.top: stuGrid.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            spacing: 8
            Repeater {
                model: reward.categories
                delegate: Rectangle {
                    readonly property bool on: win.cat === modelData
                    height: 40
                    width: lbl2.implicitWidth + 24
                    radius: height / 2
                    color: on ? "#d90fa88f" : (cm.pressed ? "#4dffffff" : "#3dffffff")
                    Text {
                        id: lbl2
                        anchors.centerIn: parent
                        text: modelData
                        color: on ? "#ffffff" : Theme.textPrimary
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
                color: Theme.textSecondary; font.pixelSize: 17; font.family: Theme.fontFamily
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

        // 抽谁：学生 / 小组
        Row {
            anchors.top: parent.top; anchors.topMargin: 68
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: ["学生", "小组"]
                delegate: Rectangle {
                    readonly property bool on: win.pickKind === index
                    width: 96; height: 44; radius: 22
                    color: on ? "#d90fa88f" : (km.pressed ? "#4dffffff" : "#3dffffff")
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: on ? "#ffffff" : Theme.textPrimary
                        font.pixelSize: 16; font.bold: on; font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: km
                        anchors.fill: parent
                        onClicked: { win.pickKind = index; win.picked = [] }
                    }
                }
            }
        }

        Row {
            anchors.top: parent.top; anchors.topMargin: 122
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Text {
                text: "抽"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.fontFamily
            }
            PointsPill { id: pickCount; from: 1; to: 5; value: 1; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: win.pickKind === 0 ? "名学生" : "个小组"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.fontFamily
            }
            CuteButton {
                tone: "primary"; text: "开始抽"
                implicitWidth: 112; implicitHeight: 50; fontSize: 18
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.doPick()
            }
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
                    color: Theme.textPrimary
                    font.pixelSize: win.picked.length > 1 ? 24 : 32
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }
            Text {
                text: win.picked.length ? "" : "点「开始抽」"
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.textMuted; font.pixelSize: 15; font.family: Theme.fontFamily
            }
        }

        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            CuteButton {
                tone: "primary"; text: "加分"
                implicitWidth: 104; implicitHeight: 52; fontSize: 19
                usable: win.picked.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyPicked(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 104; implicitHeight: 52; fontSize: 19
                usable: win.picked.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyPicked(false)
            }
            CuteButton {
                tone: "secondary"; text: "再抽"
                implicitWidth: 104; implicitHeight: 52; fontSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.doPick()
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
                color: Theme.textMuted; font.pixelSize: 15; font.family: Theme.fontFamily
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
                color: Theme.textPrimary
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
        var n = pts.value
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
        //    否则会把 ‹ × 🔒 的点击一起吃掉。
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
        LockBtn { anchors.right: parent.right; anchors.rightMargin: 52; anchors.verticalCenter: parent.verticalCenter }
        CloseBtn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.centerIn: parent
            text: parent.title
            color: Theme.textPrimary
            font.pixelSize: 19; font.bold: true; font.family: Theme.fontFamily
        }
    }

    component BackBtn: Rectangle {
        id: bb
        width: 44; height: 44; radius: 22
        color: bma.pressed ? "#40ffffff" : "#20ffffff"
        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 26; color: Theme.textPrimary }
        MouseArea { id: bma; anchors.fill: parent; onClicked: win.mode = 1 }
    }

    component CloseBtn: Rectangle {
        id: cb
        width: 44; height: 44; radius: 22
        color: cma.pressed ? "#40ffffff" : "#20ffffff"
        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 22; color: Theme.textPrimary }
        MouseArea { id: cma; anchors.fill: parent; onClicked: win.mode = 0 }
    }

    // 锁定开关：锁着=卡片固定在原地（防止误拖）；解锁=可按标题栏拖动
    component LockBtn: Rectangle {
        id: lb
        width: 44; height: 44; radius: 22
        color: lma.pressed ? "#40ffffff" : (win.cardLocked ? "#20ffffff" : "#4d0fa88f")
        Text {
            anchors.centerIn: parent
            text: win.cardLocked ? "🔒" : "🔓"
            font.pixelSize: 18
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
        color: Theme.accentDark
        font.pixelSize: 15
        font.family: Theme.fontFamily
    }
}
