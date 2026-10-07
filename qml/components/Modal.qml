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
    // 想更透就往 #ccffffff 调、想更实就往 #f5ffffff 调，只改这一个值。
    property color panelColor: "#e8ffffff"
    signal closed()

    anchors.fill: parent
    color: "#33000000"
    visible: open
    opacity: 0
    z: 90
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

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
                    width: parent.width - 40
                    text: root.title
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSection
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    width: 28; height: 28; radius: Theme.radiusPill
                    color: Theme.bgTop
                    Text { text: "✕"; anchors.centerIn: parent; color: Theme.textSecondary; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.hide() }
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
