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
        // 搜索（照搬积分商店那一套）：
        //   · 默认就是**全班视图**（不再有「全班」按钮）
        //   · 输入即按 姓名/学号 模糊过滤下拉；选人即切单人模式
        //   · 选中后搜索栏右侧出现「×」，点它即清空并**回到全班视图**（见下面的 Connections）
        StudentPicker {
            id: picker
            width: 260
            anchors.verticalCenter: parent.verticalCenter
            // 「隐藏姓名」要一起管住下拉里的名字 —— 否则卡片上藏了、下拉里照样看得见
            nameHidden: root.hideName
            onPicked: (id) => { root.mode = "single"; root.query = id }
        }
        // 选中项被清掉（点「×」）→ 回到全班视图。
        // 用 Connections 监听而不是在各处手动改，这样"×"、点别处、Esc 等任何清空路径都覆盖。
        Connections {
            target: picker
            function onCurrentIdChanged() {
                if (picker.currentId === "") { root.mode = "all"; root.query = "" }
            }
        }
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            EyeButton {
                eyeOpen: !root.hideName
                onClicked: root.hideName = !root.hideName
            }
            Text {
                // 显示的是**当前状态**（不是点击后的动作）：已隐藏 / 已显示
                text: root.hideName ? "已隐藏" : "已显示"
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
