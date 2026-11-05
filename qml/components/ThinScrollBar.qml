import QtQuick
import QtQuick.Controls

// 全站统一细圆角滚动条（自动隐藏版）：
//   · 可见宽度 4px、圆角 2px，无轨道背景；
//   · 静止时完全透明，不干扰画面；
//   · 滚动（滚轮 / 触摸拖动 / 拖滑块）时出现，停止约 0.9s 后淡出；
//   · 鼠标移到滚动条上时也会出现（触摸屏没有 hover，就由滚动触发）；
//   · 内容不需要滚动（size >= 1）时永远不显示。
//   · 颜色跟随主题的次要文字色，静止 35% / 悬停 60% / 按下 80%。
ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    minimumSize: 0.06
    property bool autoHide: true

    // 最近是否滚动过：position 一变就亮起，停手后由 Timer 关掉
    property bool _recent: false
    // 初始化阶段布局会改一次 position，别让它闪一下滚动条
    property bool _ready: false
    readonly property bool _engaged: root.hovered || root.pressed
                                      || (root._ready && root.active) || root._recent
    opacity: (root.size >= 1.0) ? 0 : ((!root.autoHide || root._engaged) ? 1 : 0)
    Behavior on opacity {
        NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
    }

    Component.onCompleted: readyTimer.start()
    Timer {
        id: readyTimer
        interval: 350
        onTriggered: root._ready = true
    }
    Timer {
        id: idleTimer
        interval: 900
        repeat: false
        onTriggered: root._recent = false
    }
    onPositionChanged: {
        if (root._ready && root.size < 1.0) {
            root._recent = true
            idleTimer.restart()
        }
    }
    onSizeChanged: {
        if (root.size >= 1.0) {
            root._recent = false
            idleTimer.stop()
        }
    }

    // 不画轨道，只留一根细细的滑块。
    // 外层 contentItem 做成 12px 的透明"抓握区"（触摸屏也好拖），
    // 里面真正画出来的仍是 4px 细条 —— 抓握区落在页面右侧预留的 14px 空隙里，
    // 所以视觉上既细、又不会压住卡片。
    background: Item {}

    contentItem: Item {
        implicitWidth: root.orientation === Qt.Vertical ? 12 : 40
        implicitHeight: root.orientation === Qt.Vertical ? 40 : 12

        Rectangle {
            width: root.orientation === Qt.Vertical ? 4 : parent.width
            height: root.orientation === Qt.Vertical ? parent.height : 4
            anchors.centerIn: parent
            radius: 2
            color: Theme.textSecondary
            opacity: root.pressed ? 0.80 : (root.hovered ? 0.60 : 0.35)
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }
    }
}
