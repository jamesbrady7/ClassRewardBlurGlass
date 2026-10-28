import QtQuick
import "../components"

// 课堂快捷悬浮球（测试版 · 独立窗口，不改主程序）
// ─────────────────────────────────────────────────────────────
// 形态：球 →(点) **四个独立气泡**从球边弹出 →(点) 批量 / 抽取 / 设置
//      气泡层再点一下球 = 收回；卡片左上 ‹ 回气泡层、右上 × 直接回球
//
// 触摸优先：**全程只用单指点击/拖动**，不依赖 hover、不依赖右键
//   · 点球 = 弹出气泡；按住拖动 = 挪位置（位移 >8px 才算拖）
//   · 按住球 1.2 秒 = 退出（球边填一圈进度，中途松手取消）
//   · 所有可点区域 ≥ 68px，字 ≥ 17px
//
// 毛玻璃：本窗口**不用系统 Acrylic**（那会把整个矩形窗口都糊上，圆形球会露方角）。
//   改为自绘：Python 每 260ms 抓「窗口背后的桌面」→ 每个元素各自 FrostedPanel 模糊 + 形状遮罩。
//   窗口尺寸只在三种形态间切换，不逐帧改，避免闪烁。
Window {
    id: win

    visible: true
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
           | (floatNoActivate ? Qt.WindowDoesNotAcceptFocus : 0)

    property int backdropVersion: 0
    property bool floatNoActivate: true

    property int mode: 0                 // 0=球 1=气泡 2=批量 3=抽取 4=设置
    property var selGroups: []
    property string cat: ""
    property var picked: []
    property string flashMsg: ""
    property real holdP: 0

    readonly property bool isBall: mode === 0 || mode === 1
    readonly property bool isCard: mode >= 2

    width: 100; height: 100
    x: Math.max(16, Screen.width - width - 28)
    y: Math.max(16, Screen.height - height - 140)

    // ── 窗口尺寸跟着形态走，锚定**右下角**（球默认在右下，卡片向左上长） ──
    onModeChanged: applySize(mode)
    function applySize(m) {
        var right = win.x + win.width
        var bottom = win.y + win.height
        if (m === 0)      { win.width = 100; win.height = 100 }
        else if (m === 1) { win.width = 360; win.height = 360 }
        else if (m === 2) { win.width = 412; win.height = 396 }
        else if (m === 3) { win.width = 412; win.height = 340 }
        else              { win.width = 412; win.height = 208 }
        win.x = Math.max(12, Math.min(right - win.width, Screen.width - win.width - 12))
        win.y = Math.max(12, Math.min(bottom - win.height, Screen.height - win.height - 12))
    }

    // ── 背后桌面截图（各元素毛玻璃的模糊源） ──
    // 背后桌面截图：既是各元素 FrostedPanel 的模糊源，也顺便当窗口"背景"。
    // 它是可见的（ShaderEffectSource 需要有东西可渲染），但因为本窗口已被排除在抓图之外，
    // 画出来的就是**真实的桌面**，静止画面下与"透明"看不出差别（代价：最多 260ms 的滞后）。
    Image {
        id: backdrop
        anchors.fill: parent
        source: "image://floatbackdrop/v" + backdropVersion
        fillMode: Image.PreserveAspectCrop
        cache: false
    }

    // ══════════════════════════════════════════════════════════
    //  球（0 / 1 态都可见，气泡层里它还是"收起"按钮）
    // ══════════════════════════════════════════════════════════
    Item {
        id: ballItem
        width: 100; height: 100
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: win.isBall

        FrostedPanel {
            anchors.fill: parent
            source: backdrop
            radius: width / 2
            glassBlur: true
            tint: "#aaffffff"
            shadow: true
            shadowColor: "#4a1a2230"
        }

        Text {
            anchors.centerIn: parent
            text: "⚡"
            font.pixelSize: 40
            scale: ballMa.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }

        // 长按退出：沿球边填充一圈进度
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

        Timer { id: holdTimer; interval: 1200; onTriggered: Qt.quit() }
        NumberAnimation {
            id: holdRing
            target: win; property: "holdP"
            from: 0; to: 1; duration: 1200
        }

        MouseArea {
            id: ballMa
            anchors.fill: parent
            property point grab: Qt.point(0, 0)
            property real wx: 0
            property real wy: 0
            property bool moved: false

            onPressed: function(m) {
                grab = Qt.point(win.x + m.x, win.y + m.y)
                wx = win.x; wy = win.y
                moved = false
                holdRing.restart()
                holdTimer.restart()
            }
            onPositionChanged: function(m) {
                // 窗口坐标 + 窗口位置 = 光标屏幕坐标；拖动时两者同步移动，所以这个和是稳定的
                var gx = win.x + m.x, gy = win.y + m.y
                if (!moved && Math.abs(gx - grab.x) + Math.abs(gy - grab.y) <= 8) return
                if (!moved) { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }
                moved = true
                win.x = wx + (gx - grab.x)
                win.y = wy + (gy - grab.y)
            }
            onReleased: {
                holdRing.stop(); holdTimer.stop(); win.holdP = 0
                if (moved) return
                win.mode = (win.mode === 1) ? 0 : 1      // 点球：弹出气泡 / 再点收回
            }
            onCanceled: { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }
        }
    }

    // ══════════════════════════════════════════════════════════
    //  1 · 四个独立气泡（从球边错峰弹出）
    // ══════════════════════════════════════════════════════════
    Item {
        id: menuLayer
        anchors.fill: parent
        visible: win.mode === 1

        // 展开进度：OutBack 回弹 = "啵"地弹出来的手感
        property real t: win.mode === 1 ? 1 : 0
        Behavior on t {
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        Repeater {
            // ⚡批量 / 🎲抽取 / 🖥完整界面 / ⚙设置
            model: [
                { g: "👥", m: 2, tip: "批量" },
                { g: "🎲", m: 3, tip: "抽取" },
                { g: "🖥", m: -1, tip: "完整界面" },
                { g: "⚙", m: 4, tip: "设置" }
            ]
            delegate: Item {
                id: bub
                // 从"左"到"上"铺开 90°：球在右下角，气泡全落在屏幕内
                readonly property real ang: (180 - index * 30) * Math.PI / 180
                // 错峰：每个气泡比前一个晚 10% 开始
                readonly property real p: Math.max(0, Math.min(1, (menuLayer.t - index * 0.10) / 0.70))
                readonly property real dist: 180 * (0.62 + 0.38 * p)   // 从球心飞出去
                readonly property real bx: menuLayer.width - 50
                readonly property real by: menuLayer.height - 50

                width: 84; height: 84
                x: bx + Math.cos(ang) * dist - width / 2
                y: by - Math.sin(ang) * dist - height / 2
                scale: 0.25 + 0.75 * p
                opacity: p

                FrostedPanel {
                    anchors.fill: parent
                    source: backdrop
                    radius: width / 2
                    glassBlur: true
                    tint: bma.pressed ? "#d9ffffff" : "#b3ffffff"
                    shadow: true
                    shadowColor: "#4a1a2230"
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.g
                    font.pixelSize: 32
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

        // 占位按钮的提示（贴在窗口左上角，不挡气泡）
        FlashLine {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.top: parent.top; anchors.topMargin: 14
        }
    }

    // ══════════════════════════════════════════════════════════
    //  2·3·4 · 功能卡片（共用一块玻璃底）
    // ══════════════════════════════════════════════════════════
    FrostedPanel {
        anchors.fill: parent
        visible: win.isCard
        source: backdrop
        radius: 22
        glassBlur: true
        tint: "#aaffffff"
        shadow: true
        shadowColor: "#4a1a2230"
    }

    // ── 2 · 批量：按小组加分 ──
    Item {
        anchors.fill: parent
        visible: win.mode === 2

        CardHead { title: "批量加分" }

        Flow {
            id: groupFlow
            anchors.top: parent.top; anchors.topMargin: 74
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            spacing: 10
            Repeater {
                model: reward.groups
                delegate: BigChip {
                    text: modelData.name
                    active: win.selGroups.indexOf(modelData.id) >= 0
                    onTapped: {
                        var a = win.selGroups.slice()
                        var i = a.indexOf(modelData.id)
                        if (i >= 0) a.splice(i, 1); else a.push(modelData.id)
                        win.selGroups = a
                    }
                }
            }
        }

        Flow {
            anchors.top: groupFlow.bottom; anchors.topMargin: 14
            anchors.left: parent.left; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 20
            spacing: 10
            Repeater {
                model: reward.categories
                delegate: BigChip {
                    text: modelData
                    small: true
                    active: win.cat === modelData
                    onTapped: win.cat = (win.cat === modelData ? "" : modelData)
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
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
                implicitWidth: 116; implicitHeight: 56; fontSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyPoints(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 116; implicitHeight: 56; fontSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyPoints(false)
            }
        }

        FlashLine {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 84
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── 3 · 抽取 ──
    Item {
        anchors.fill: parent
        visible: win.mode === 3

        CardHead { title: "随机抽取" }

        Row {
            anchors.top: parent.top; anchors.topMargin: 72
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Text {
                text: "抽"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textSecondary; font.pixelSize: 17; font.family: Theme.fontFamily
            }
            PointsPill { id: pickCount; from: 1; to: 5; value: 1; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "名学生"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textSecondary; font.pixelSize: 17; font.family: Theme.fontFamily
            }
            CuteButton {
                tone: "primary"; text: "开始抽"
                implicitWidth: 120; implicitHeight: 52; fontSize: 18
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.doPick()
            }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 10
            spacing: 4
            Repeater {
                model: win.picked
                delegate: Text {
                    text: modelData.name
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.textPrimary
                    font.pixelSize: win.picked.length > 1 ? 26 : 34
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }
            Text {
                text: win.picked.length ? "" : "点「开始抽」"
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.textMuted; font.pixelSize: 16; font.family: Theme.fontFamily
            }
        }

        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            CuteButton {
                tone: "primary"; text: "加分"
                implicitWidth: 108; implicitHeight: 56; fontSize: 19
                usable: win.picked.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyPicked(true)
            }
            CuteButton {
                tone: "danger"; text: "扣分"
                implicitWidth: 108; implicitHeight: 56; fontSize: 19
                usable: win.picked.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.applyPicked(false)
            }
            CuteButton {
                tone: "secondary"; text: "再抽"
                implicitWidth: 108; implicitHeight: 56; fontSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: win.doPick()
            }
        }

        FlashLine {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 84
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── 4 · 设置 ──
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
                implicitWidth: 220; implicitHeight: 56; fontSize: 19
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: Qt.quit()
            }
            Text {
                text: "提示：长按球 1.2 秒也可以退出"
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.textMuted; font.pixelSize: 15; font.family: Theme.fontFamily
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    Timer { id: flashTimer; interval: 1600; onTriggered: win.flashMsg = "" }

    // ══════════════════════════════════════════════════════════
    //  业务
    // ══════════════════════════════════════════════════════════
    function flash(t) { win.flashMsg = t; flashTimer.restart() }

    function applyPoints(isAdd) {
        if (!win.selGroups.length) { flash("请先点选小组"); return }
        if (!win.cat) { flash("请先选操作分类"); return }
        var ids = []
        for (var i = 0; i < reward.students.length; i++)
            if (win.selGroups.indexOf(reward.students[i].groupId) >= 0) ids.push(reward.students[i].id)
        if (!ids.length) { flash("所选出的小组里还没有学生"); return }
        var n = pts.value
        var msg = reward.batchPointChange(ids.join(','), n, isAdd, win.cat)
        flash(msg ? msg : ((isAdd ? "＋" : "－") + n + " 分已应用"))
    }

    function doPick() {
        var raw = reward.randomPickStudents(pickCount.value)
        var out = []
        for (var i = 0; i < raw.length; i++) {
            for (var j = 0; j < reward.students.length; j++) {
                if (reward.students[j].id === raw[i].id) { out.push(reward.students[j]); break }
            }
        }
        win.picked = out
    }

    function applyPicked(isAdd) {
        if (!win.picked.length) return
        if (!win.cat) { flash("请先在「批量」里选一次分类"); return }
        var n = pts.value
        var names = []
        for (var i = 0; i < win.picked.length; i++) {
            var s = win.picked[i]
            reward.pointChange(s.id, n, isAdd, win.cat)
            names.push(s.name)
        }
        flash((isAdd ? "＋" : "－") + n + " 分：" + names.join("、"))
    }

    // ══════════════════════════════════════════════════════════
    //  小部件
    // ══════════════════════════════════════════════════════════
    component CardHead: Item {
        property string title: ""
        anchors.top: parent.top; anchors.topMargin: 14
        anchors.left: parent.left; anchors.leftMargin: 20
        anchors.right: parent.right; anchors.rightMargin: 20
        height: 44

        BackBtn { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
        CloseBtn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.centerIn: parent
            text: parent.title
            color: Theme.textPrimary
            font.pixelSize: 20; font.bold: true; font.family: Theme.fontFamily
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

    component BigChip: Rectangle {
        id: bc
        property string text: ""
        property bool active: false
        property bool small: false
        signal tapped()
        height: small ? 44 : 52
        width: lbl.implicitWidth + (small ? 28 : 34)
        radius: height / 2
        color: bc.active ? "#d90fa88f" : (bma2.pressed ? "#40ffffff" : "#33ffffff")
        border.color: bc.active ? "transparent" : "#59ffffff"
        border.width: bc.active ? 0 : 1
        Behavior on color { ColorAnimation { duration: 110 } }
        Text {
            id: lbl
            anchors.centerIn: parent
            text: bc.text
            color: bc.active ? "#ffffff" : Theme.textPrimary
            font.pixelSize: bc.small ? 16 : 18
            font.bold: bc.active
            font.family: Theme.fontFamily
        }
        MouseArea { id: bma2; anchors.fill: parent; onClicked: bc.tapped() }
    }

    component FlashLine: Text {
        text: win.flashMsg
        visible: text !== ""
        color: Theme.accentDark
        font.pixelSize: 15
        font.family: Theme.fontFamily
    }
}
