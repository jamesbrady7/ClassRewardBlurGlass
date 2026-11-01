import QtQuick
import "../components"
import "../tools"

// 工具箱：工具入口列表 → 点击进入具体工具。
// 以后新增工具只需要：① 在 tools 模型里加一条；② 在 toolValue/toolStatus 里加分支；
// ③ 新建 qml/tools/XxxTool.qml 并在下面加一个 Component + Loader 分支。
//
// 计时状态全部在共享的 TimerHub（Main.qml 里的唯一实例），
// 与悬浮球用的是同一个对象 —— 无论从哪边开始，切换模式都不中断。
Column {
    id: root

    // 由 Main.qml 传入（property QtObject timerHub: timerHubObj）
    property QtObject hub: null

    // "" = 工具列表；"countdown" / "stopwatch" = 已进入某个工具
    property string activeTool: ""

    spacing: Theme.spacing

    // ── 工具清单（入口卡）──
    readonly property var tools: [
        { key: "countdown", title: "倒计时", icon: "clock",
          soft: Theme.accentSoft, deep: Theme.accent },
        { key: "stopwatch", title: "秒表", icon: "stopwatch",
          soft: Theme.blueSoft, deep: Theme.blue }
    ]

    function toolTitle(key) {
        for (var i = 0; i < tools.length; i++)
            if (tools[i].key === key) return tools[i].title
        return ""
    }
    function toolValue(key) {
        if (!hub) return ""
        if (key === "countdown") return hub.fmtCountdown()
        if (key === "stopwatch") return hub.fmtSw(hub.swElapsed)
        return ""
    }
    function toolStatus(key) {
        if (!hub) return ""
        if (key === "countdown") {
            if (hub.timerDone) return "时间到"
            if (hub.timerRunning) return "计时中"
            if (!hub.timerIdle) return "已暂停"
        } else if (key === "stopwatch") {
            if (hub.swRunning) return "计时中"
            if (hub.swElapsed > 0) return "已暂停"
        }
        return ""
    }
    function statusFg(s) {
        return s === "时间到" ? Theme.red
             : s === "计时中" ? Theme.green
             : Theme.amber
    }
    function statusBg(s) {
        return s === "时间到" ? Theme.redSoft
             : s === "计时中" ? Theme.greenSoft
             : Theme.amberSoft
    }

    // ── 页标题 ──
    Row {
        width: parent.width
        height: 30
        spacing: 8
        Rectangle {
            width: 4; height: 20; radius: 2
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "工具箱"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: body
        width: parent.width
        height: parent.height - 30 - root.spacing

        // ══════════════════════════════════════════════════════
        //  工具列表：每个工具一张入口卡（带实时状态与当前值）
        // ══════════════════════════════════════════════════════
        Item {
            id: listLayer
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.activeTool === "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Grid {
                anchors.top: parent.top
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2
                spacing: 16

                Repeater {
                    model: root.tools

                    delegate: Card {
                        required property var modelData

                        width: 360
                        height: 190
                        radius: Theme.radius
                        cardColor: Theme.cardGlass
                        shadow: true
                        liftOnHover: true

                        Item {
                            anchors.fill: parent
                            anchors.margins: 20

                            Item {
                                width: parent.width
                                height: 46

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12

                                    Rectangle {
                                        width: 46; height: 46; radius: 14
                                        color: modelData.soft
                                        anchors.verticalCenter: parent.verticalCenter
                                        CanvasIcon {
                                            anchors.centerIn: parent
                                            name: modelData.icon
                                            width: 23; height: 23
                                            color: modelData.deep
                                        }
                                    }
                                    Text {
                                        text: modelData.title
                                        color: Theme.textPrimary
                                        font.pixelSize: 19
                                        font.weight: Font.DemiBold
                                        font.family: Theme.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                StatusPill {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.toolStatus(modelData.key)
                                    fg: root.statusFg(text)
                                    bg: root.statusBg(text)
                                }
                            }

                            // 当前值：不用进工具就能看到进度
                            Text {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: root.toolValue(modelData.key)
                                color: Theme.textSecondary
                                font.pixelSize: 30
                                font.weight: Font.DemiBold
                                font.family: Theme.fontFamily
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                text: "›"
                                color: Theme.textMuted
                                font.pixelSize: 24
                                font.family: Theme.fontFamily
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTool = modelData.key
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  工具内容：返回 + 工具名 + 状态 + 工具本体
        // ══════════════════════════════════════════════════════
        Item {
            id: toolLayer
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.activeTool === "" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Column {
                anchors.fill: parent
                spacing: 12

                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        CuteButton {
                            tone: "secondary"
                            text: "‹ 工具箱"
                            implicitWidth: 96; implicitHeight: 34; fontSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.activeTool = ""
                        }
                        Text {
                            text: root.toolTitle(root.activeTool)
                            color: Theme.textPrimary
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StatusPill {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.toolStatus(root.activeTool)
                            fg: root.statusFg(text)
                            bg: root.statusBg(text)
                        }
                    }
                }

                Card {
                    width: Math.min(parent.width, 900)
                    height: parent.height - 36 - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.radius
                    cardColor: Theme.cardGlass
                    shadow: true

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 24
                        sourceComponent: root.activeTool === "countdown" ? countdownComp
                                       : root.activeTool === "stopwatch" ? stopwatchComp
                                       : null
                    }
                }
            }
        }
    }

    // ── 工具本体（新增工具在这里挂一个 Component + 上面的 Loader 分支）──
    Component {
        id: countdownComp
        CountdownTool { anchors.fill: parent; hub: root.hub }
    }
    Component {
        id: stopwatchComp
        StopwatchTool { anchors.fill: parent; hub: root.hub }
    }

    // 状态胶囊：只在"计时中 / 已暂停 / 时间到"时出现
    component StatusPill: Rectangle {
        id: pill
        property string text: ""
        property color fg: Theme.textMuted
        property color bg: "transparent"

        visible: text !== ""
        width: visible ? pillLabel.implicitWidth + 20 : 0
        height: 24
        radius: height / 2
        color: bg

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.text
            color: pill.fg
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }
    }
}
