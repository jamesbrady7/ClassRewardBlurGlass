import QtQuick

// 共享计时器：主界面的「工具箱」和悬浮球的倒计时/秒表共用**同一个实例**。
// 只放状态和逻辑，不放界面；两边谁改都会通知另一边。
//
// 实例在 Main.qml 里创建，main.py 在加载悬浮球之前把它注册成
// context property "timerHub"；悬浮球 QML 直接用 timerHub.xxx。
// 用 Item 而不是 QtObject：QML 的 QtObject 没有 default property，
// 里面的两个 Timer 无处挂载（会报 "Cannot assign to non-existent default property"）。
// 这里没有视觉内容，尺寸保持 0，作为窗口的不可见子项存在。
Item {
    id: hub

    // ── 倒计时 ──
    // 计时按"结束时间戳"算，界面卡顿/后台都不会累积漂移。
    property real timerTotal: 5 * 60 * 1000
    property real timerLeft: 5 * 60 * 1000
    property bool timerRunning: false
    property bool timerDone: false
    property double timerEndAt: 0

    // 编辑态的时/分/秒各自独立存（0-99）；调整时互不影响，开始时才归一化。
    property int editH: 0
    property int editM: 5
    property int editS: 0

    readonly property int secLeft: Math.max(0, Math.ceil(timerLeft / 1000))
    readonly property int tH: Math.floor(secLeft / 3600)
    readonly property int tM: Math.floor((secLeft % 3600) / 60)
    readonly property int tS: secLeft % 60
    // 编辑态显示用户设置的单位值；运行/暂停时显示剩余（会进位）
    readonly property int dispH: timerIdle ? editH : tH
    readonly property int dispM: timerIdle ? editM : tM
    readonly property int dispS: timerIdle ? editS : tS
    readonly property int hT: Math.floor(dispH / 10)
    readonly property int hO: dispH % 10
    readonly property int mT: Math.floor(dispM / 10)
    readonly property int mO: dispM % 10
    readonly property int sT: Math.floor(dispS / 10)
    readonly property int sO: dispS % 10
    readonly property bool timerIdle: !timerRunning && !timerDone
                                      && Math.abs(timerLeft - timerTotal) < 1

    // 0=倒计时 1=秒表（两边共享同一个选中页）
    property int timerTab: 0
    signal countdownFinished()

    Timer {
        id: cdTimer
        interval: 200
        repeat: true
        running: hub.timerRunning
        onTriggered: hub.tickTimer()
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    function fmtSw(ms) {
        var t = Math.max(0, Math.round(ms))
        var cs = Math.floor(t / 10) % 100
        var totalS = Math.floor(t / 1000)
        var h = Math.floor(totalS / 3600)
        var m = Math.floor(totalS / 60) % 60
        var s = totalS % 60
        return (h > 0 ? h + ":" : "") + pad2(m) + ":" + pad2(s) + "." + pad2(cs)
    }

    // 倒计时大数字（编辑态显示设置值，运行态显示剩余）
    function fmtCountdown() {
        return pad2(dispH) + ":" + pad2(dispM) + ":" + pad2(dispS)
    }

    // 逐位调节（悬浮球的六位数字轮）：十位/个位都是 0-9 循环
    function adjustDigit(unit, place, delta) {
        if (!timerIdle) return
        var v = unit === 0 ? editH : unit === 1 ? editM : editS
        var tens = Math.floor(v / 10)
        var ones = v % 10
        if (place === 0) tens = (tens + delta + 10) % 10
        else             ones = (ones + delta + 10) % 10
        setEditUnit(unit, tens * 10 + ones)
    }

    // 整单位调节（主界面工具箱用）
    function adjustUnit(unit, delta) {
        if (!timerIdle) return
        var v = unit === 0 ? editH : unit === 1 ? editM : editS
        setEditUnit(unit, v + delta)
    }

    function setEditUnit(unit, v) {
        v = Math.max(0, Math.min(99, Math.round(v)))
        if (unit === 0) editH = v
        else if (unit === 1) editM = v
        else editS = v
        // 开始后按真实秒数走；上限 99:59:59（编辑态单位本身允许 99）
        var totalS = Math.min(99 * 3600 + 59 * 60 + 59,
                              editH * 3600 + editM * 60 + editS)
        timerTotal = totalS * 1000
        timerLeft = timerTotal
    }

    function startTimer() {
        if (timerTotal <= 0) return
        if (timerDone || timerLeft <= 0) {
            timerDone = false
            timerLeft = timerTotal
        }
        timerEndAt = Date.now() + timerLeft
        timerRunning = true
    }

    function pauseTimer() {
        timerLeft = Math.max(0, timerEndAt - Date.now())
        timerRunning = false
    }

    function resetTimer() {
        timerRunning = false
        timerDone = false
        timerLeft = timerTotal
    }

    function tickTimer() {
        var left = timerEndAt - Date.now()
        if (left <= 0) {
            timerLeft = 0
            timerRunning = false
            timerDone = true
            countdownFinished()
        } else {
            timerLeft = left
        }
    }

    // ── 秒表（分段计时：每次「计次」记下距上一次的用时 = 一组的时间）──
    property real swBase: 0
    property real swElapsed: 0
    property bool swRunning: false
    property double swStartAt: 0
    property var swSplits: []        // [{seg, total}]

    Timer {
        id: swTimer
        interval: 32
        repeat: true
        running: hub.swRunning
        onTriggered: hub.swElapsed = hub.swBase + (Date.now() - hub.swStartAt)
    }

    function swToggle() {
        if (swRunning) {
            // 按实际时间结算（别用上一帧的 swElapsed，会少 0~32ms）
            swBase = swBase + (Date.now() - swStartAt)
            swElapsed = swBase
            swRunning = false
        } else {
            swStartAt = Date.now()
            swRunning = true
        }
    }

    function swReset() {
        swRunning = false
        swBase = 0
        swElapsed = 0
        swSplits = []
    }

    function swLap() {
        if (!swRunning && swElapsed <= 0) return
        var now = swRunning ? swBase + (Date.now() - swStartAt) : swElapsed
        swElapsed = now
        var a = swSplits.slice()
        var prev = a.length > 0 ? a[a.length - 1].total : 0
        a.push({ seg: now - prev, total: now })
        swSplits = a
    }
}
