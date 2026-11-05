import QtQuick
import QtQuick.Controls
import "../components"

// 今日分数截图预览（独立小窗）：
//   · 「保存今日分数截图」时先渲染海报（poster）、存到桌面，再把这个窗口弹出来；
//   · 窗口可拖动、可关闭，默认置顶；右上角开关可切换置顶/不置顶；
//   · 置顶状态走 QSettings 持久化（拔 U 盘、重启软件后仍保持）。
//   · 海报本身固定浅色、深色字 —— 不跟昼夜主题变，保证学校系统录入时清楚。
Window {
    id: win

    property var info: ({})
    property string statusText: ""
    property bool statusOk: true
    // 自动化验证钩子：Python 侧 setProperty('pendingInfo', {...}) 即可打开
    // （QMetaObject.invokeMethod 调 QML 函数在本环境无效，只能靠属性变化触发）
    property var pendingInfo: null
    onPendingInfoChanged: {
        if (pendingInfo) {
            var v = pendingInfo
            pendingInfo = null
            openWith(v)
        }
    }
    // 默认置顶；scorePrefs 在离屏探针里可能没注册 → 用 typeof 兜底
    property bool topmost: (typeof scorePrefs !== 'undefined' && scorePrefs)
                           ? scorePrefs.topmost : true

    visible: false
    title: "今日分数预览"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    width: 540
    // 海报完整展示；超过屏幕可用高度时改为窗口内滚动（海报本身仍完整，用于截图）
    height: Math.min(Screen.height - 100, chromeBar.height + poster.height + 36)

    function applyTopmost(on) {
        if (typeof scorePrefs !== 'undefined' && scorePrefs)
            scorePrefs.applyTopmost(win, on)
    }

    function centerOnScreen() {
        var sx = Screen.virtualX
        var sy = Screen.virtualY
        win.x = Math.round(sx + (Screen.width - win.width) / 2)
        win.y = Math.round(sy + Math.max(24, (Screen.height - win.height) * 0.12))
    }

    function openWith(infoObj) {
        win.info = infoObj
        win.statusText = "正在保存…"
        win.statusOk = true
        topmostSwitch.checked = win.topmost
        win.show()
        win.raise()
        win.requestActivate()
        Qt.callLater(function() {
            win.centerOnScreen()
            win.applyTopmost(win.topmost)
            saveTimer.restart()
        })
    }

    function doSave() {
        if (!win.info || !win.info.url) {
            win.statusText = "没有可保存的内容"
            win.statusOk = false
            return
        }
        poster.grabToImage(function(result) {
            var ok = false
            try { ok = !!(result && result.saveToFile(win.info.url)) } catch (e) { ok = false }
            win.statusText = ok ? "已保存到桌面" : "保存失败"
            win.statusOk = ok
            if (typeof mainWin !== 'undefined' && mainWin && mainWin.toast) {
                mainWin.toast.show(ok ? ("已保存到桌面：" + (win.info.fileName || ""))
                                      : "截图保存失败，请重试", 2800, !ok)
            }
        })
    }

    Timer {
        id: saveTimer
        interval: 120
        repeat: false
        onTriggered: win.doSave()
    }

    // 窗口外形（圆角；窗口本身透明）
    Rectangle {
        id: shell
        anchors.fill: parent
        radius: 18
        color: "#f4f6fa"
        border.color: "#e2e8f0"
        border.width: 1
        clip: true

        // ===== 顶部工具条 =====
        Item {
            id: chromeBar
            width: parent.width
            height: 52

            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "今日分数预览"
                    color: "#2b3445"
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                }
                Text {
                    text: win.statusText
                    visible: text !== ""
                    color: win.statusOk ? "#15803d" : "#b91c1c"
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                }
            }

            // 拖动区（标题这一整段）；控件声明在后面 → 不会被它吃掉点击
            MouseArea {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: controls.left
                cursorShape: Qt.PointingHandCursor
                onPressed: win.startSystemMove()
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: "置顶"
                    color: "#64748b"
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                GlassSwitch {
                    id: topmostSwitch
                    width: 46
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    checked: win.topmost
                    onToggled: {
                        win.topmost = topmostSwitch.checked
                        win.applyTopmost(win.topmost)
                        if (typeof scorePrefs !== 'undefined' && scorePrefs)
                            scorePrefs.setTopmost(win.topmost)
                    }
                }
                CircleButton {
                    size: 28
                    icon: "close"
                    shadow: false
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: win.hide()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#e8edf4"
            }
        }

        // ===== 海报（可滚动展示；截图抓的是整张 poster）=====
        Flickable {
            id: view
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: chromeBar.bottom
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: poster.height + 28
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ThinScrollBar {}

            Rectangle {
                id: poster
                x: Math.round((view.width - width) / 2)
                y: 14
                width: 470
                height: posterCol.implicitHeight + 64
                radius: 18
                color: "#ffffff"
                border.color: "#eef2f7"
                border.width: 1

                Column {
                    id: posterCol
                    x: 32
                    y: 30
                    width: parent.width - 64
                    spacing: 16

                    // 班级 + 日期
                    Item {
                        width: parent.width
                        height: 28
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: reward.todayLedger.className || "当前班级"
                            color: "#1f2937"
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            font.family: Theme.fontFamily
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: reward.todayLedger.date
                            color: "#94a3b8"
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#eef2f7" }

                    // 标题
                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "英语今日分数"
                            color: "#111827"
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                            font.family: Theme.fontFamily
                        }
                        Text {
                            text: "供学校系统录入 · 加分 / 扣分 / 小组分"
                            color: "#94a3b8"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }

                    // ── 加分 ──
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: reward.todayLedger.hasEarn
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: "#15803d"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "加分"
                                color: "#15803d"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.family: Theme.fontFamily
                            }
                        }
                        Repeater {
                            model: reward.todayLedger.earn
                            delegate: Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 52; height: 22; radius: 11
                                    color: "#e8f7ee"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.category
                                        color: "#15803d"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        font.family: Theme.fontFamily
                                    }
                                }
                                Text {
                                    width: 66
                                    text: "+" + modelData.points + " 分"
                                    color: "#1f2937"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width: parent.width - 138
                                    text: modelData.ids
                                    color: "#475569"
                                    font.pixelSize: 13
                                    font.family: Theme.fontFamily
                                    font.letterSpacing: 0.6
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    // ── 扣分 ──
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: reward.todayLedger.hasDeduct
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: "#b91c1c"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "扣分"
                                color: "#b91c1c"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.family: Theme.fontFamily
                            }
                        }
                        Repeater {
                            model: reward.todayLedger.deduct
                            delegate: Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 52; height: 22; radius: 11
                                    color: "#fdecec"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.category
                                        color: "#b91c1c"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        font.family: Theme.fontFamily
                                    }
                                }
                                Text {
                                    width: 66
                                    text: "-" + modelData.points + " 分"
                                    color: "#1f2937"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    width: parent.width - 138
                                    text: modelData.ids
                                    color: "#475569"
                                    font.pixelSize: 13
                                    font.family: Theme.fontFamily
                                    font.letterSpacing: 0.6
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    // ── 小组直接分 ──
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: reward.todayLedger.hasGroup
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: "#2563eb"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "小组直接分"
                                color: "#2563eb"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.family: Theme.fontFamily
                            }
                        }
                        Repeater {
                            model: reward.todayLedger.groupEarn.concat(reward.todayLedger.groupDeduct)
                            delegate: Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 96; height: 22; radius: 11
                                    color: "#eaf1ff"
                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 12
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        color: "#2563eb"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        font.family: Theme.fontFamily
                                    }
                                }
                                Text {
                                    text: modelData.sign + modelData.points + " 分"
                                    color: modelData.sign === "-" ? "#b91c1c" : "#1f2937"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.family: Theme.fontFamily
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#eef2f7" }

                    Text {
                        text: "班级激励助手 · 今日分数汇总"
                        color: "#a8b1c0"
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
