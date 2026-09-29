import QtQuick
import QtQuick.Controls
import "../components"
import "../charts"

// 数据分析：六维雷达图 + 学习趋势折线图
Column {
    id: root

    property string mode: "all"
    property string query: ""
    property bool hideName: false

    property var items: {
        if (root.mode === "all") return reward.analysis
        var q = root.query.trim()
        return reward.analysis.filter(function(a) { return a.studentId === q })
    }

    spacing: Theme.spacing

    // 标题 + 工具栏
    Row {
        width: parent.width
        spacing: 8
        Rectangle { width: 4; height: 20; radius: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: "数据分析"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSection
            font.bold: true
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 8; height: 1 }
        CuteButton {
            tone: root.mode === "all" ? "soft" : "secondary"
            text: "全班"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { root.mode = "all"; root.query = "" }
        }
        Rectangle {
            width: 120; height: 34
            radius: Theme.radiusSmall
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.accent : Theme.inputBorder
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Text {
                visible: searchInput.text.length === 0
                text: "输入学号"
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
            }
            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                font.family: Theme.fontFamily
            }
        }
        RoundBtn {
            size: 36
            bg: Theme.accentSoft
            fg: Theme.accentDark
            icon: "search"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { if (searchInput.text.trim()) { root.mode = "single"; root.query = searchInput.text } }
        }
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            EyeButton {
                eyeOpen: !root.hideName
                onClicked: root.hideName = !root.hideName
            }
            Text {
                text: root.hideName ? "显示姓名" : "隐藏姓名"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                font.family: Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Item { width: 1; height: 1 }
        Text {
            text: root.mode === "all" ? "全班模式（" + reward.analysis.length + " 人）" : "单人模式"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            font.family: Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 内容
    ListView {
        id: list
        width: parent.width
        height: parent.height - 44
        clip: true
        spacing: 12
        // 上下留空间：卡片悬停会上浮 4px，clip 会把首/末卡裁掉
        topMargin: 10
        bottomMargin: 10
        model: root.items

        delegate: Card {
            property var student: modelData
            width: list.width
            height: 360
            radius: Theme.radius
            // 底色与学生卡片一致：半透明白玻璃（浓度要低才透得出背后，见 RosterTab 的说明）
            cardColor: "#4dffffff"
            shadow: true
            liftOnHover: true
            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        text: "#" + student.studentId + "  " + (root.hideName ? "***" : student.name)
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontBig
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }
                Row {
                    width: parent.width
                    height: 300
                    spacing: 12
                    RadarChart {
                        width: parent.width * 0.5 - 6
                        height: 300
                        scores: student.scores
                        categories: reward.categories
                    }
                    // 趋势图：日期多时可横向滚动
                    Flickable {
                        id: trendScroll
                        width: parent.width * 0.5 - 6
                        height: 300
                        contentWidth: trendChart.contentWidth
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                        TrendChart {
                            id: trendChart
                            width: trendScroll.contentWidth
                            height: 300
                            transactions: student.transactions
                        }
                    }
                }
            }
        }
    }
}
