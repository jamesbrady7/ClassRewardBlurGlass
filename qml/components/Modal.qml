import QtQuick

// 模态对话框基座：暗色遮罩 + 居中卡片 + 标题 + 入场动画
// 用法：设置 title + contentComponent，调 show() 打开
Rectangle {
    id: root

    property string title: ""
    property bool open: false
    property Component contentComponent: null   // 内容（由对话框提供）
    property Item content: contentLoader.item    // 已实例化的内容
    // 弹窗面板底色：**半透明白**（原来用 Card 的默认 Theme.surface = 纯白不透明）。
    // 本应用是毛玻璃风格，面板透一点才和整体一致 —— 能隐约看到后面被压暗的页面内容。
    // 想更透就往 #c4ffffff 调、想更实就往 #e8ffffff 调，只改这一个值。
    property color panelColor: "#d9ffffff"
    signal closed()

    anchors.fill: parent
    color: "#33000000"
    // ⚠️ 不能写 `visible: open`：hide() 里 open 一置 false，整个弹窗立刻不可见，
    //    **关闭动画根本播不出来**（只有打开有动画）。改成跟着淡出进度走 ——
    //    opacity 归零过程中保持可见，播完自然消失。
    visible: opacity > 0.001
    opacity: 0
    z: 90
    // 200ms：要覆盖住下面 Card 那条 200ms 的 scale 回弹，否则会被提前切掉
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function show() { open = true; opacity = 1 }
    function hide() { open = false; opacity = 0; closed() }

    // 点遮罩空白处关闭
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Card {
        id: card
        width: Math.min(400, parent.width - 80)
        height: Math.min(contentLoader.implicitHeight + 92, parent.height - 120)
        anchors.centerIn: parent
        cardColor: root.panelColor      // 半透明白（见上面的说明）
        shadow: true
        z: 1

        scale: root.open ? 1 : 0.94
        opacity: root.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            Row {
                width: parent.width
                height: 30
                Text {
                    width: parent.width - 38
                    text: root.title
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSection
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                // 关闭按钮：与整个软件的关闭按钮**同一套**（标题栏那颗 CircleButton：
                // 玻璃圆面 + raised 圆外双球 + close 图标 + 同款悬停/按下反馈）。
                // 原来是自绘的 28px 圆角方块 + 文字"✕"，观感和主界面不搭。
                CircleButton {
                    size: 30
                    raised: true
                    shadow: false
                    icon: "close"
                    onClicked: root.hide()
                }
            }

            Loader {
                id: contentLoader
                sourceComponent: root.contentComponent
                width: parent.width
                height: item ? item.implicitHeight : 0
            }
        }
    }
}
