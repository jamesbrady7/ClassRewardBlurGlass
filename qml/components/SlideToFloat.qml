import QtQuick

// 滑动进入（类似"滑动解锁"）：
//   按住左侧的小球 → **从左往右拖到头**才触发；没拖到阈值就松手 → 平滑弹回起点。
//   · 小球用悬浮球同款配色（marine 蓝潮 + 白色四芒星），一眼知道"拖它 = 叫出悬浮球"
//   · 右侧三个箭头是引导：静止时依次亮起（提示"往右滑"），拖动时按进度逐个点亮
//   · 拖到阈值后文字变成「松开进入」，松开才真正触发 —— 避免手滑误触
//   · 用相对位移拖动（不把小球瞬移到鼠标下），单击任何位置都不会触发
Item {
    id: root

    property string text: "进入悬浮球"
    property string doneText: "松开进入"
    property bool enabled: true
    signal activated()

    implicitWidth: 160
    implicitHeight: 36
    width: implicitWidth
    height: implicitHeight

    readonly property real pad: 4
    readonly property real knobSize: height - pad * 2
    readonly property real maxX: width - knobSize - pad * 2

    property real knobX: 0
    property bool dragging: false
    property real _pressX: 0
    property real _pressKnobX: 0
    // 0..1 拖动进度；>=0.9 才算"到头"（留一点容错，手抖也能触发）
    readonly property real p: maxX > 0 ? Math.max(0, Math.min(1, knobX / maxX)) : 0
    readonly property bool armed: p >= 0.9

    // 拖动时立即跟手；松手后由 Behavior 平滑归位 / 滑到底
    Behavior on knobX {
        enabled: !root.dragging
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // ── 轨道 ──
    // 用主题的 glass 两档（不是写死的白色）：白天浅、夜间深，文字对比度两种模式都成立
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: (ma.containsMouse || root.dragging) ? Theme.fillGlassHover : Theme.fillGlass
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // ── 引导文字 ──
    Text {
        x: root.pad + root.knobSize + 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.armed ? root.doneText : root.text
        // 拖到头：变主题青绿 + 重新亮起（"松开进入"要看得最清楚）
        color: root.armed ? Theme.accentDark : Theme.textPrimary
        // 拖到一半时小球会压过文字，所以拖动期间先淡下去；armed 再亮回来
        opacity: root.armed ? 1.0 : 0.85 * Math.max(0.08, 1 - root.p / 0.62)
        font.pixelSize: Theme.fontSmall - 1
        font.family: Theme.fontFamily
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // ── 引导箭头 ──
    // 静止：三个箭头按 1.5s 的波依次亮起；拖动：按进度 i/3 逐个点亮
    Canvas {
        id: arrows
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 16
        property real progress: root.p
        property bool sliding: root.dragging
        property color ink: Theme.textPrimary
        onProgressChanged: requestPaint()
        onSlidingChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            var c = getContext("2d")
            c.reset()
            c.lineWidth = 1.7
            c.lineCap = "round"
            c.lineJoin = "round"
            for (var i = 0; i < 3; i++) {
                var a
                if (arrows.sliding || arrows.progress > 0.01) {
                    a = 0.20 + 0.68 * Math.max(0, Math.min(1, arrows.progress * 3 - i))
                } else {
                    a = 0.20 + 0.62 * Math.max(0, Math.sin((root.phase - i * 0.16) * Math.PI * 2))
                }
                c.strokeStyle = String(Qt.rgba(arrows.ink.r, arrows.ink.g, arrows.ink.b, a))
                var x0 = i * 6 + 1.5
                c.beginPath()
                c.moveTo(x0, 3)
                c.lineTo(x0 + 5, 8)
                c.lineTo(x0, 13)
                c.stroke()
            }
        }
    }

    // 引导波相位：60ms 一跳（约 16fps）就够了，比逐帧重绘省
    property real phase: 0
    Timer {
        interval: 60
        repeat: true
        running: !root.dragging && root.p < 0.01
        onTriggered: root.phase = (root.phase + 0.04) % 1.0
    }

    // ── 小球（悬浮球同款：marine 杂糅面 + 白四芒星）──
    Item {
        id: knob
        x: root.pad + root.knobX
        anchors.verticalCenter: parent.verticalCenter
        width: root.knobSize; height: root.knobSize
        scale: root.dragging ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        SoftShadow {
            anchors.fill: parent
            anchors.margins: -6
            anchors.topMargin: -3; anchors.bottomMargin: -3
            softColor: Qt.rgba(0.30, 0.33, 0.48, root.dragging ? 0.30 : 0.22)
        }
        IridescentFill {
            anchors.fill: parent
            circle: true
            fade: 0.05
            scheme: "marine"
        }
        CanvasIcon {
            anchors.centerIn: parent
            name: "sparkle"
            width: 14; height: 14
            color: "#ffffff"
        }
    }

    // ── 拖动 ──
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: function(m) {
            root.dragging = true
            root._pressX = m.x
            root._pressKnobX = root.knobX
        }
        onPositionChanged: function(m) {
            if (!root.dragging) return
            // 相对位移：小球不会被瞬移到鼠标下，也不会"点右边就白得一大段进度"
            root.knobX = Math.max(0, Math.min(root.maxX,
                               root._pressKnobX + (m.x - root._pressX)))
        }
        onReleased: {
            if (!root.dragging) return
            root.dragging = false
            if (root.armed) {
                root.knobX = root.maxX
                root.activated()
                resetTimer.restart()
            } else {
                root.knobX = 0        // 没到头 → 弹回去（这时不许触发）
            }
        }
        onCanceled: {
            root.dragging = false
            root.knobX = 0
        }
    }

    // 触发后回到起点：主界面会立刻收起，所以这一步用户看不到；
    // 但下次回到主界面时必须是"未滑动"的初始态。
    Timer {
        id: resetTimer
        interval: 320
        onTriggered: root.knobX = 0
    }
}
