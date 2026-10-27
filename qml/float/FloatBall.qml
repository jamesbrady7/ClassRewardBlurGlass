import QtQuick
import "../components"

// 课堂快捷悬浮球（测试版 · 独立窗口，不改主程序）
// ─────────────────────────────────────────────────────────────
// 形态：球 →(点) 菜单 4 个图标 →(点) 批量 / 抽取 / 设置
//      菜单与卡片里都有 × 收回到球；设置里有"退出悬浮球"。
//
// 触摸优先：**全程只用单指点击/拖动**，不依赖 hover、不依赖右键
//   · 点球 = 展开菜单（按压瞬间有高亮，触摸屏没有悬停）
//   · 按着球拖动 = 挪位置；位移超过 8px 才算拖，否则算点
//   · 所有可点区域 ≥ 64px，字 ≥ 17px（讲台前两米要看得清）
//
// 毛玻璃：本窗口**不用系统 Acrylic**（那会把整个矩形窗口都糊上，球的四个方角会露出来）。
//   改为自绘：FrostedPanel 抓「窗口背后的桌面截图」→ 高斯模糊 → 圆角/圆形遮罩 → 叠 tint。
//   截图由 Python 每 260ms 抓一次（image://floatbackdrop），并已把本窗口排除在抓图之外。
Window {
    id: win

    visible: true
    color: "transparent"
    // Tool=不进任务栏；StaysOnTop=压住 PPT；DoesNotAcceptFocus=不抢 PPT 的键盘焦点
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
           | (floatNoActivate ? Qt.WindowDoesNotAcceptFocus : 0)

    // 由 Python 驱动：抓图版本号（变一次就重新取一次 image://floatbackdrop）
    property int backdropVersion: 0
    // 是否"不抢焦点"（Windows WS_EX_NOACTIVATE）。对 PPT 放映友好，但先留开关便于排查输入问题。
    property bool floatNoActivate: true

    property int mode: 0                 // 0=球 1=菜单 2=批量 3=抽取 4=设置
    property var selGroups: []           // 批量：选中的小组 id
    property string cat: ""              // 操作分类
    property var picked: []              // 抽取结果
    property string flashMsg: ""         // 操作反馈（触摸屏没有 toast，就地显示）
    property real holdP: 0               // 长按进度 0..1（填满即退出）

    readonly property bool isBall: mode === 0

    // 球/卡片的尺寸（窗口 = 可见内容，避免透明区域挡住下面的 PPT 点击）
    width: 100; height: 100
    x: Math.max(16, Screen.width - width - 28)
    y: Math.max(16, Screen.height - height - 140)

    // ── 窗口尺寸随形态变化，锚定**右下角**（球默认在右下，卡片向左上长） ──
    onModeChanged: applySize(mode)
    function applySize(m) {
        var right = win.x + win.width
        var bottom = win.y + win.height
        if (m === 0)      { win.width = 100; win.height = 100 }
        else if (m === 1) { win.width = 352; win.height = 136 }
        else if (m === 2) { win.width = 412; win.height = 396 }
        else if (m === 3) { win.width = 412; win.height = 340 }
        else              { win.width = 412; win.height = 208 }
        win.x = Math.max(12, Math.min(right - win.width, Screen.width - win.width - 12))
        win.y = Math.max(12, Math.min(bottom - win.height, Screen.height - win.height - 12))
    }

    // ── 背后桌面截图（毛玻璃的模糊源） ──
    Image {
        id: backdrop
        anchors.fill: parent
        source: "image://floatbackdrop/v" + backdropVersion
        fillMode: Image.PreserveAspectCrop
        cache: false
    }

    // ── 玻璃面：球是圆的、卡片是圆角 ──
    FrostedPanel {
        anchors.fill: parent
        source: backdrop
        radius: win.isBall ? width / 2 : 22
        glassBlur: true
        tint: "#aaffffff"          // 比主程序的卡片（30% 白）实一些：它是浮在 PPT 上的独立面板
        shadow: true
        shadowColor: "#4a1a2230"
    }

    // ══════════════════════════════════════════════════════════
    //  0 · 球
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.isBall

        Text {
            anchors.centerIn: parent
            text: "⚡"
            font.pixelSize: 40
            // 触摸没有 hover，按压瞬间给一点缩放的"按下去"手感
            scale: ballMa.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }

        // 长按退出：沿球边缘填充一圈进度（1.2 秒填满 → 松手前填满即退出）
        Canvas {
            anchors.fill: parent
            property real p: win.holdP          // 绑定到进度；p 一变就重绘
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
            property point grab: Qt.point(0, 0)      // 按下时的**屏幕坐标**
            property real wx: 0
            property real wy: 0
            property bool moved: false

            onPressed: function(m) {
                grab = Qt.point(win.x + m.x, win.y + m.y)
                wx = win.x; wy = win.y
                moved = false
                holdRing.restart()          // 长按退出：环形进度开始填
                holdTimer.restart()
            }
            onPositionChanged: function(m) {
                // 窗口坐标 + 窗口位置 = 光标屏幕坐标；拖动时两者同步移动，所以这个和是稳定的
                var gx = win.x + m.x, gy = win.y + m.y
                if (!moved && Math.abs(gx - grab.x) + Math.abs(gy - grab.y) <= 8) return
                if (!moved) { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }   // 开始拖动 = 取消长按
                moved = true
                win.x = wx + (gx - grab.x)
                win.y = wy + (gy - grab.y)
            }
            onReleased: {
                holdRing.stop(); holdTimer.stop(); win.holdP = 0
                if (!moved) win.mode = 1                  // 位移没超过阈值 → 当成一次点击
            }
            onCanceled: { holdRing.stop(); holdTimer.stop(); win.holdP = 0 }
        }
    }

    // ══════════════════════════════════════════════════════════
    //  1 · 菜单：四个图标
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 1

        // 四个图标贴在底部一行；× 单独占右上角，不与按钮重叠
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            IconBtn { glyph: "⚡"; onTapped: win.mode = 2 }
            IconBtn { glyph: "🎲"; onTapped: win.mode = 3 }
            IconBtn { glyph: "🖥"; onTapped: { win.flashMsg = "完整界面：合并后接上"; flashTimer.restart() } }
            IconBtn { glyph: "⚙"; onTapped: win.mode = 4 }
        }
        CloseBtn { anchors.right: parent.right; anchors.rightMargin: 10; anchors.top: parent.top; anchors.topMargin: 8 }
    }

    // ══════════════════════════════════════════════════════════
    //  2 · 批量：按小组加分
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: win.mode === 2

        CardHead { title: "批量加分" }

        // 小组（可多选）
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

        // 分类（单选）
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

        // 分值 + 加减
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

        FlashLine { }
    }

    // ══════════════════════════════════════════════════════════
    //  3 · 抽取：抽到谁 → 直接加分
    // ══════════════════════════════════════════════════════════
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

        // 结果：大字
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

        FlashLine { }
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
    //  就地反馈（触摸屏没有 hover 提示，操作结果必须立刻看到）
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
        // 抽中的是快照，用当前数据补齐（同随机抽取页的做法）
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
        // 每张卡片都能**一次点击**回到球（触摸屏上少一次跳转就是少一次误触）
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

    component IconBtn: Rectangle {
        id: ib
        property string glyph: ""
        signal tapped()
        width: 68; height: 68; radius: 24
        color: ima.pressed ? "#59ffffff" : "#26ffffff"
        border.color: "#66ffffff"; border.width: 1
        Behavior on color { ColorAnimation { duration: 90 } }
        scale: ima.pressed ? 0.94 : 1.0
        Text { anchors.centerIn: parent; text: ib.glyph; font.pixelSize: 32 }
        MouseArea { id: ima; anchors.fill: parent; onClicked: ib.tapped() }
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
        anchors.bottom: parent.bottom; anchors.bottomMargin: 84
        anchors.horizontalCenter: parent.horizontalCenter
        text: win.flashMsg
        visible: text !== ""
        color: Theme.accentDark
        font.pixelSize: 15
        font.family: Theme.fontFamily
    }
}
