import QtQuick
import QtQuick.Effects
import QtQuick.Dialogs
import "components"
import "dialogs"
import "tabs"

Window {
    id: mainWin
    width: 1600
    height: 1020
    minimumWidth: 1100
    minimumHeight: 750
    visible: true
    title: "班级激励助手"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window   // 无边框，标题栏自绘以统一风格

    // 背景层暴露给子页面的毛玻璃面板（FrostedPanel.source）
    property alias frostedSource: backgroundLayer

    // 把常用控件/对话框暴露成窗口属性，供子页面 mainWin.xxx 访问
    property alias toast: toastBox
    property alias dlgPrompt: dlgPromptBox
    property alias dlgConfirm: dlgConfirmBox
    property alias dlgStudent: dlgStudentBox
    property alias dlgImport: dlgImportBox
    property alias dlgGroup: dlgGroupBox
    property alias dlgReward: dlgRewardBox
    property alias dlgMove: dlgMoveBox
    property alias dlgBackpack: dlgBackpackBox
    property alias dlgHistory: dlgHistoryBox
    property alias dlgGradeClass: dlgGradeClassBox

    // ============================================================
    // 背景层：圆角 + 渐变 + 装饰色块（毛玻璃标题栏的模糊源）
    // ============================================================
    Rectangle {
        id: backgroundLayer
        anchors.fill: parent
        radius: 12
        clip: true
        border.color: Theme.border
        border.width: 1
        // 桌面穿透模式：背景交给 DWM（Acrylic 在窗后实时糊化桌面），不再自绘
        visible: !systemGlass

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.bgTop }
                GradientStop { position: 1.0; color: Theme.bgBottom }
            }
        }
        Rectangle { x: -140; y: -100; width: 460; height: 460; radius: 230; color: "#1f16b69b" }
        Rectangle { x: parent.width - 320; y: 60; width: 400; height: 400; radius: 200; color: "#1ce76a9e" }
        Rectangle { x: parent.width * 0.42; y: -180; width: 380; height: 380; radius: 190; color: "#1a8b6fe8" }
        Rectangle { x: parent.width * 0.62; y: parent.height - 260; width: 420; height: 420; radius: 210; color: "#1ae8a93c" }
    }

    // ============================================================
    // 顶部毛玻璃标题栏
    // ============================================================
    FrostedPanel {
        id: titleBar
        width: parent.width - 48
        height: 58
        radius: Theme.radius
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        source: backgroundLayer
        glassBlur: !systemGlass       // 穿透模式：模糊交给 DWM，这里只留半透明 tint

        MouseArea {
            anchors.fill: parent
            onPressed: mainWin.startSystemMove()
            onDoubleClicked: mainWin.visibility === Window.Maximized ? mainWin.showNormal() : mainWin.showMaximized()
        }

        Row {
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            z: 2

            // Logo 图标：照搬原型——底色用原型"圆形按钮 13"的配色（marine 蓝潮薄荷心），
            // 中间是原型的四芒星矢量图标（原来是文字"★"，靠字体渲染、不可靠）
            Item {
                width: 36; height: 36
                IridescentFill {
                    anchors.fill: parent
                    rad: 11
                    scheme: "marine"
                }
                CanvasIcon {
                    anchors.centerIn: parent
                    name: "sparkle"
                    width: 24; height: 24
                    color: "#ffffff"     // 按用户要求用白星（实心白，压得住底色）
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "班级激励助手"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    font.family: Theme.fontFamily
                }
                Text {
                    text: "让每个小进步都被看见"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                }
            }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            z: 2

            Rectangle {
                width: 52; height: 24; radius: Theme.radiusPill
                color: "transparent"
                border.color: Theme.border
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "V3.16"
                    anchors.centerIn: parent
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                }
            }
            // 窗口按钮：照搬原型的做法 —— CircleButton + raised（圆外双球立体）
            //   最小化 / 放大·还原 / 关闭 同一套逻辑，只有图标不同
            CircleButton {
                size: 30
                raised: true
                shadow: false
                icon: "minus"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mainWin.showMinimized()
            }
            CircleButton {
                size: 30
                raised: true
                shadow: false
                icon: mainWin.visibility === Window.Maximized ? "restore" : "maximize"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mainWin.visibility === Window.Maximized ? mainWin.showNormal() : mainWin.showMaximized()
            }
            CircleButton {
                size: 30
                raised: true
                shadow: false
                icon: "close"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mainWin.close()
            }
        }
    }

    // ============================================================
    // 全局班级栏：位于标题正下方——先选班级，再对该班级操作（导出/导入贴最右）
    // ============================================================
    Item {
        id: globalBar
        width: parent.width - 48
        height: 40
        anchors.top: titleBar.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            // 班级切换：**照搬原型的分段 Tab**（底槽 + 滑动白胶囊 + 移动时拉伸形变）
            SegmentedTabs {
                id: classTabs
                anchors.verticalCenter: parent.verticalCenter
                labels: {
                    var a = []
                    for (var i = 0; i < reward.classes.length; i++) a.push(reward.classes[i].name)
                    return a
                }
                currentIndex: {
                    for (var i = 0; i < reward.classes.length; i++)
                        if (reward.classes[i].current) return i
                    return 0
                }
                onActivated: function(i) { reward.setCurrentClass(reward.classes[i].id) }
                // 右键改名/删除：原型没有这个，是本应用原有的能力，保留
                onRightClicked: function(i, item) {
                    mainWin.openClassMenu(item, reward.classes[i].id, reward.classes[i].name)
                }
            }
            RoundBtn {
                size: 34
                accent: true; scheme: "aurora"   // 加号：原型圆形按钮 16（极光杂糅）
                fg: "#ffffff"
                icon: "plus"
                hint: "新建班级"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: dlgGradeClassBox.openClassDialog(function(name) { reward.addClass(name) })
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            CuteButton {
                text: "导出"
                onClicked: exportDialog.open()
            }
            CuteButton {
                text: "导入"
                onClicked: importDialog.open()
            }
        }
    }

    // ============================================================
    // 主体：左侧整条纵向导航 + 右侧（统计条/页面）
    // ============================================================
    Row {
        id: contentRow
        width: parent.width - 48
        anchors.top: globalBar.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        // 左导航整条轨道（从标题栏下方直达底部，离顶近）
        SideNav {
            id: appTabs
            width: 180
            height: contentRow.height
            blurSource: backgroundLayer      // 玻璃外壳的模糊源
            titles: ["花名册", "小组榜", "随机抽取", "批量操作", "积分商店", "每日历史", "数据分析"]
            currentIndex: 0
            onActivated: function(idx) { appTabs.currentIndex = idx }
        }

        Column {
            width: contentRow.width - 180 - 12
            spacing: 12

            // ===== 统计条（本周扣分达人 / 进步之星：深底浅字）=====
            Row {
                width: parent.width
                height: 30
                spacing: 14
                Pill { text: "🔻 扣分达人(>3)"; bg: Theme.red; fg: "#ffffff"; bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    id: deductText
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                    text: {
                        var arr = reward.weeklyStats ? reward.weeklyStats.deduct : []
                        return arr.length ? arr.map(function(d) { return d.student_id + " " + d.name + " -" + d.points }).join("  ")
                                          : "无"
                    }
                }
                Item { width: 16; height: 1 }
                Pill { text: "🔺 进步之星(+2)"; bg: Theme.green; fg: "#ffffff"; bold: true; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    id: earnText
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                    text: {
                        var arr = reward.weeklyStats ? reward.weeklyStats.earn : []
                        return arr.length ? arr.map(function(e) { return e.student_id + " " + e.name + " " + e.category + "+" + e.diff }).join("  ")
                                          : "无"
                    }
                }
                Item { width: 16; height: 1 }
                Text {
                    text: "✨ 每周更新"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.fontFamily
                }
            }

            // ===== 页面宿主（7 页，交叉淡化切换）=====
            Item {
                id: pageHost
                width: parent.width
                height: contentRow.height - (30 + Theme.spacing)   // 直接绑 id，避开 Column implicitHeight 循环
                clip: true

                RosterTab { id: page0; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                GroupTab { id: page1; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                RandomPickTab { id: page2; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                BatchTab { id: page3; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                ShopTab { id: page4; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                HistoryTab { id: page5; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                AnalysisTab { id: page6; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
            }
        }
    }

    // 页面交叉淡化调度：新页淡入与旧页淡出同时进行，避免切换"闪"。
    property var _pages: []
    property int _curPage: -1
    Component.onCompleted: {
        _pages = [page0, page1, page2, page3, page4, page5, page6]
        showPage(0)
    }
    NumberAnimation { id: animIn
        property Item node: null
        target: node; property: "opacity"; to: 1.0
        duration: 180; easing.type: Easing.OutCubic
    }
    // 外部把 currentIndex 改为 N（含脚本/程序化切换）也走 showPage
    Connections {
        target: appTabs
        function onCurrentIndexChanged() {
            var v = appTabs.currentIndex
            if (v >= 0 && v !== mainWin._curPage) mainWin.showPage(v)
        }
    }
    function showPage(i) {
        if (i < 0 || i >= 7 || i === _curPage) return
        var prev = _curPage
        _curPage = i
        appTabs.currentIndex = i
        // 旧页立即收起（不淡出复现），避免"上一个 tab 闪一下"
        if (prev >= 0) { _pages[prev].visible = false; _pages[prev].z = 0; _pages[prev].opacity = 1 }
        // 新页快速淡入
        for (var k = 0; k < 7; k++) {
            if (k !== i) { _pages[k].visible = false; _pages[k].z = 0 }
        }
        var np = _pages[i]
        np.visible = true
        np.z = 2
        np.opacity = 0
        animIn.stop(); animIn.node = np; animIn.start()
    }

    // ============================================================
    // 班级右键菜单（重命名 / 删除）
    // ============================================================
    Rectangle {
        id: menuOverlay
        anchors.fill: parent
        color: "transparent"
        visible: classMenu.open || groupMenu.open
        z: 280
        MouseArea { anchors.fill: parent; onClicked: { hideClassMenu(); hideGroupMenu() } }
    }
    Rectangle {
        id: classMenu
        property string cid: ""
        property string cname: ""
        property bool open: false
        width: 152
        height: 92
        visible: open
        z: 290
        radius: 10
        color: "#f4f7fb"
        border.color: "#c6d1de"
        border.width: 1
        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2
            Rectangle { // 重命名
                width: parent.width
                height: 38
                radius: 6
                color: "transparent"
                Rectangle { // 悬停高亮：恒定主色，只动透明度（避免灰阶过渡）
                    anchors.fill: parent
                    radius: 6
                    color: Theme.accent
                    opacity: mRename.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Text { // 平时
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "重命名班级"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mRename.containsMouse ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Text { // 悬停
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "重命名班级"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mRename.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: mRename
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        hideClassMenu()
                        dlgGradeClassBox.openRenameDialog(function(name) {
                            if (name && classMenu.cid) reward.renameClass(classMenu.cid, name)
                        }, classMenu.cname)
                    }
                }
            }
            Rectangle { // 细分隔线，让菜单成整体
                width: parent.width - 10
                height: 1
                color: "#dbe3ec"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle { // 删除
                width: parent.width
                height: 38
                radius: 6
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.red
                    opacity: mDelete.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "删除班级"
                    color: Theme.red
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mDelete.containsMouse ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "删除班级"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mDelete.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: mDelete
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var c = classMenu.cid
                        var cn = classMenu.cname
                        hideClassMenu()
                        dlgConfirmBox.openConfirm("删除班级", "确定删除「" + cn + "」？该班级的学生与记录将一并删除。", function() {
                            reward.setCurrentClass(c)
                            if (reward.deleteClass(c)) toastBox.show("已删除 " + cn)
                        })
                    }
                }
            }
        }
    }

    function openClassMenu(btn, cid, name) {
        classMenu.cid = cid
        classMenu.cname = name
        var p = btn.mapToItem(null, 0, 0)
        classMenu.x = Math.max(4, Math.min(p.x, mainWin.width - classMenu.width - 8))
        classMenu.y = p.y + btn.height + 4
        classMenu.open = true
    }
    function hideClassMenu() { classMenu.open = false }

    // ---------- 小组右键菜单（改名 / 删除）----------
    Rectangle {
        id: groupMenu
        property string gid: ""
        property string gname: ""
        property bool open: false
        width: 152
        height: 92
        visible: open
        z: 290
        radius: 10
        color: "#f4f7fb"
        border.color: "#c6d1de"
        border.width: 1
        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2
            Rectangle {
                width: parent.width; height: 38; radius: 6; color: "transparent"
                Rectangle {
                    anchors.fill: parent; radius: 6; color: Theme.accent
                    opacity: mGren.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "更改组名"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mGren.containsMouse ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "更改组名"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mGren.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: mGren
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        hideGroupMenu()
                        dlgPromptBox.openPrompt("重命名小组", "小组名称：", function(n) {
                            if (n && groupMenu.gid) reward.renameGroup(groupMenu.gid, n)
                        })
                    }
                }
            }
            Rectangle {
                width: parent.width - 10
                height: 1
                color: "#dbe3ec"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                width: parent.width; height: 38; radius: 6; color: "transparent"
                Rectangle {
                    anchors.fill: parent; radius: 6; color: Theme.red
                    opacity: mGdel.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "删除小组"
                    color: Theme.red
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mGdel.containsMouse ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "删除小组"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontBody
                    font.family: Theme.fontFamily
                    opacity: mGdel.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: mGdel
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var gn = groupMenu.gname
                        var gid = groupMenu.gid
                        hideGroupMenu()
                        dlgConfirmBox.openConfirm("删除小组", "确定删除「" + gn + "」？", function() {
                            if (reward.deleteGroup(gid)) toastBox.show("已删除 " + gn)
                            else toastBox.show("小组内还有学生，请先移走")
                        })
                    }
                }
            }
        }
    }
    function openGroupMenu(btn, gid, name) {
        groupMenu.gid = gid
        groupMenu.gname = name
        var p = btn.mapToItem(null, 0, 0)
        groupMenu.x = Math.max(4, Math.min(p.x, mainWin.width - groupMenu.width - 8))
        groupMenu.y = Math.max(4, Math.min(p.y + btn.height + 4, mainWin.height - groupMenu.height - 8))
        groupMenu.open = true
    }
    function hideGroupMenu() { groupMenu.open = false }

    // ============================================================
    // 全局轻提示
    // ============================================================
    Toast { id: toastBox }

    // ============================================================
    // 对话框（各 Tab 通过 mainWin.xxx 打开）
    // ============================================================
    PromptDialog { id: dlgPromptBox }
    ConfirmDialog { id: dlgConfirmBox }
    StudentDialog { id: dlgStudentBox }
    ImportDialog { id: dlgImportBox }
    GroupDialog { id: dlgGroupBox }
    RewardDialog { id: dlgRewardBox }
    MoveDialog { id: dlgMoveBox }
    BackpackDialog { id: dlgBackpackBox }
    HistoryDialog { id: dlgHistoryBox }
    GradeClassDialog { id: dlgGradeClassBox }

    // ============================================================
    // 导出 / 导入文件选择
    // ============================================================
    FileDialog {
        id: exportDialog
        title: "导出数据"
        fileMode: FileDialog.SaveFile
        nameFilters: ["JSON (*.json)"]
        onAccepted: {
            if (reward.exportData(selectedFile)) toastBox.show("导出成功")
            else toastBox.show("导出失败")
        }
    }
    FileDialog {
        id: importDialog
        title: "导入数据"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON (*.json)"]
        onAccepted: {
            var err = reward.importData(selectedFile)
            if (err) toastBox.show("导入失败：" + err)
            else toastBox.show("导入成功")
        }
    }

    // ============================================================
    // 无边框窗口：边缘 / 角落缩放把手
    // ============================================================
    property int _rsw
    property int _rsh
    property int _rsx
    property int _rsy
    property int _rsmx
    property int _rsmy

    function _resizeBegin(mx, my) {
        _rsw = mainWin.width; _rsh = mainWin.height
        _rsx = mainWin.x; _rsy = mainWin.y
        _rsmx = mx; _rsmy = my
    }
    function _resizeApply(mode, mx, my) {
        var dx = mx - _rsmx
        var dy = my - _rsmy
        if (mode.indexOf("L") >= 0) { mainWin.x = _rsx + dx; mainWin.width = Math.max(mainWin.minimumWidth, _rsw - dx) }
        if (mode.indexOf("R") >= 0) { mainWin.width = Math.max(mainWin.minimumWidth, _rsw + dx) }
        if (mode.indexOf("T") >= 0) { mainWin.y = _rsy + dy; mainWin.height = Math.max(mainWin.minimumHeight, _rsh - dy) }
        if (mode.indexOf("B") >= 0) { mainWin.height = Math.max(mainWin.minimumHeight, _rsh + dy) }
    }

    MouseArea { x: mainWin.width - 5; y: 5; width: 5; height: mainWin.height - 10; cursorShape: Qt.SizeHorCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("R", mouse.x, mouse.y) }
    MouseArea { x: 5; y: mainWin.height - 5; width: mainWin.width - 10; height: 5; cursorShape: Qt.SizeVerCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("B", mouse.x, mouse.y) }
    MouseArea { x: mainWin.width - 5; y: mainWin.height - 5; width: 5; height: 5; cursorShape: Qt.SizeFDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("RB", mouse.x, mouse.y) }
    MouseArea { x: 0; y: mainWin.height - 5; width: 8; height: 5; cursorShape: Qt.SizeBDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("LB", mouse.x, mouse.y) }
    MouseArea { x: 0; y: 5; width: 5; height: mainWin.height - 10; cursorShape: Qt.SizeHorCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("L", mouse.x, mouse.y) }
    MouseArea { x: 5; y: 0; width: mainWin.width - 10; height: 5; cursorShape: Qt.SizeVerCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("T", mouse.x, mouse.y) }
    MouseArea { x: mainWin.width - 5; y: 0; width: 5; height: 8; cursorShape: Qt.SizeFDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("TR", mouse.x, mouse.y) }
    MouseArea { x: 0; y: 0; width: 8; height: 8; cursorShape: Qt.SizeBDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y); onPositionChanged: _resizeApply("LT", mouse.x, mouse.y) }
}
