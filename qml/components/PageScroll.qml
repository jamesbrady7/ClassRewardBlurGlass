import QtQuick
import QtQuick.Controls

// 页面级纵向滚动容器：
//   · 窗口够高时页面占满、滚动条不出现；
//   · 窗口被缩小到低于 minContentHeight 时，页面保持可用布局高度，
//     由这条滚动条/滚轮把整页上下移动，而不是把内容硬压扁/裁掉。
// 用法：
//   PageScroll {
//       RosterTab { anchors.fill: parent }
//   }
// PageScroll 里的子项会自动挂到 content 上，并以 content 为 parent。
Flickable {
    id: root

    property real minContentHeight: 780
    // 右侧给自动隐藏的滚动条留出的空隙：页面内容不再贴着滚动条，
    // 滚动时细条出现在这 14px 里，不会压住卡片。
    property real scrollGutter: 14

    default property alias contentData: content.data

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: Math.max(height, root.minContentHeight)

    ScrollBar.vertical: ThinScrollBar {}

    Item {
        id: content
        width: root.width - root.scrollGutter
        height: root.contentHeight
    }
}
