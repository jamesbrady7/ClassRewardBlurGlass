import QtQuick
import QtQuick.Effects

// 圆角卡片（毛玻璃版）：原来是"不透明白 + MultiEffect 硬投影"。
//   · 投影改为 SoftShadow（径向渐变、边缘真正模糊；且对**半透明**卡片也成立——
//     MultiEffect 的 layer 投影是按整块矩形算的，卡片一透明就会露出一圈生硬的影）
//   · 新增悬停上浮：位移与投影由**同一个 lift 派生** → 天然同步
// 调用方接口保持不变（radius / cardColor / borderColor / shadow），另加 liftOnHover。
Item {
    id: root

    property color cardColor: Theme.surface
    property color borderColor: Theme.border
    property bool shadow: false
    property bool liftOnHover: false      // 悬停轻微上浮（默认关，避免影响不该动的卡片）
    property real liftPx: 4
    property real radius: Theme.radius
    default property alias content: host.data

    // 悬停抬升：**唯一动画源**，位移与投影都从它派生
    property real lift: (root.liftOnHover && hover.hovered) ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 400; easing.type: Easing.OutSine } }
    HoverHandler { id: hover }

    // 投影：锚在卡片的静止位置，再反向位移抵消卡片的上移 → **投影留在地面**，距离被拉开
    SoftShadow {
        visible: root.shadow
        anchors.fill: parent
        anchors.margins: -(16 + 6 * root.lift)
        anchors.topMargin: -4
        anchors.bottomMargin: -(10 + 8 * root.lift)
        transform: Translate { y: root.liftPx * root.lift }
        softColor: Qt.rgba(0.12, 0.15, 0.22, 0.16 + 0.14 * root.lift)
    }

    // 上浮的是**"卡片本体 + 卡片上的所有内容"这一整坨**（投影不跟着，反向位移留在地面）。
    // ⚠️ 内容必须和 bg 在同一个位移容器里：先前只给 bg 挂了 Translate，
    //    结果卡片面浮上去、上面的组件留在原地，两者分离了。
    Item {
        id: mover
        anchors.fill: parent
        transform: Translate { y: -root.liftPx * root.lift }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: root.radius
            color: root.cardColor
            border.color: root.borderColor
            border.width: 1
        }

        Item { id: host; anchors.fill: parent }
    }
}
