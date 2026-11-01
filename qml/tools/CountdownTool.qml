import QtQuick
import "../components"

// 倒计时工具（工具箱里的一项）：只负责显示与操作，状态全部在共享 TimerHub。
Item {
    id: root
    property QtObject hub: null

    // 数字轮区域：占满按钮上方
    Item {
        anchors.fill: parent
        anchors.bottomMargin: 64

        Row {
            id: dialRow
            anchors.centerIn: parent
            spacing: 36
            // 窗口缩到设计最小尺寸时按可用宽度整体等比缩小（点击区随 transform 一起缩）
            scale: Math.min(1, (parent.width - 8) / Math.max(1, implicitWidth))
            transformOrigin: Item.Center

            UnitDial {
                unit: 0
                value: root.hub ? root.hub.dispH : 0
                live: root.hub ? root.hub.timerIdle : false
                done: root.hub ? root.hub.timerDone : false
            }
            UnitDial {
                unit: 1
                value: root.hub ? root.hub.dispM : 0
                live: root.hub ? root.hub.timerIdle : false
                done: root.hub ? root.hub.timerDone : false
            }
            UnitDial {
                unit: 2
                value: root.hub ? root.hub.dispS : 0
                live: root.hub ? root.hub.timerIdle : false
                done: root.hub ? root.hub.timerDone : false
            }
        }
    }

    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 48

        Row {
            anchors.centerIn: parent
            height: parent.height
            spacing: 12

            CuteButton {
                tone: "primary"
                text: !root.hub ? "开始"
                      : root.hub.timerRunning ? "暂停"
                      : root.hub.timerDone ? "再来一次"
                      : (root.hub.timerLeft > 0
                         && root.hub.timerLeft < root.hub.timerTotal ? "继续" : "开始")
                implicitWidth: 132; implicitHeight: 48; fontSize: 17
                usable: root.hub && root.hub.timerTotal > 0
                onClicked: {
                    if (!root.hub) return
                    if (root.hub.timerRunning) root.hub.pauseTimer()
                    else root.hub.startTimer()
                }
            }
            CuteButton {
                tone: "secondary"
                text: "重置"
                implicitWidth: 96; implicitHeight: 48; fontSize: 17
                onClicked: if (root.hub) root.hub.resetTimer()
            }
        }
    }

    // ── 单个数字轮：▲ / 数字 / ▼（每一位都是 0-9 循环）──
    component SpinDigit: Item {
        id: ds
        property int digit: 0
        property bool live: true
        property bool done: false
        signal stepped(int delta)

        width: 58
        height: 158

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            text: "▲"
            color: upHit.containsMouse && ds.live ? Theme.accent
                   : ds.live ? Theme.textSecondary : Theme.textMuted
            opacity: ds.live ? 1 : 0.55
            font.pixelSize: 12
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: upHit
            anchors.horizontalCenter: parent.horizontalCenter
            y: -6; width: 46; height: 40
            hoverEnabled: true
            enabled: ds.live
            cursorShape: Qt.PointingHandCursor
            onClicked: ds.stepped(1)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36
            text: String(ds.digit)
            // 运行/暂停时只是"不可调"（箭头置灰），读数本身必须保持清晰
            color: ds.done ? Theme.amber : Theme.textPrimary
            font.pixelSize: 68
            font.bold: true
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 126
            text: "▼"
            color: downHit.containsMouse && ds.live ? Theme.accent
                   : ds.live ? Theme.textSecondary : Theme.textMuted
            opacity: ds.live ? 1 : 0.55
            font.pixelSize: 12
            font.family: Theme.fontFamily
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: downHit
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120; width: 46; height: 36
            hoverEnabled: true
            enabled: ds.live
            cursorShape: Qt.PointingHandCursor
            onClicked: ds.stepped(-1)
        }
    }

    // 一个单位（时 / 分 / 秒）：两位数字轮 + 单位名
    component UnitDial: Item {
        id: dial
        property int unit: 0
        property int value: 0
        property bool live: true
        property bool done: false

        width: 128
        height: 188

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            spacing: 8
            SpinDigit {
                digit: Math.floor(dial.value / 10)
                live: dial.live
                done: dial.done
                onStepped: function(d) { if (root.hub) root.hub.adjustDigit(dial.unit, 0, d) }
            }
            SpinDigit {
                digit: dial.value % 10
                live: dial.live
                done: dial.done
                onStepped: function(d) { if (root.hub) root.hub.adjustDigit(dial.unit, 1, d) }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 164
            text: dial.unit === 0 ? "时" : dial.unit === 1 ? "分" : "秒"
            color: Theme.textMuted
            font.pixelSize: 13
            font.family: Theme.fontFamily
        }
    }
}
