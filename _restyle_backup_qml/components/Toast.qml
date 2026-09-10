import QtQuick

// 轻提示：底部滑入 + 淡出。
// show(message, ms, warn)：ms 停留毫秒(默认1600)，warn 为警示色(用于必须注意的提示)。
Rectangle {
    id: root

    property string message: ""
    property bool active: false
    property bool warn: false

    width: Math.max(320, txt.implicitWidth + 56)
    height: 46
    radius: Theme.radiusPill
    color: root.warn ? "#d93a2b" : "#ee26313b"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 28
    opacity: 0
    visible: opacity > 0
    z: 100

    Text {
        id: txt
        text: root.message
        anchors.centerIn: parent
        color: "#ffffff"
        font.pixelSize: Theme.fontBody
        font.bold: root.warn
        font.family: Theme.fontFamily
    }

    NumberAnimation on opacity { id: fade; duration: 220; easing.type: Easing.OutCubic }
    NumberAnimation on anchors.bottomMargin { id: slide; from: 0; to: 28; duration: 260; easing.type: Easing.OutCubic }

    Timer { id: hideTimer; interval: 1600; onTriggered: { fade.to = 0; fade.running = true } }

    function show(msg, ms, warn) {
        root.message = msg
        root.warn = !!warn
        if (ms) hideTimer.interval = ms
        fade.to = 1; fade.running = true
        slide.to = 28; slide.running = true
        hideTimer.start()
    }
}
