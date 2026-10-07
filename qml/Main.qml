import QtQuick
import QtQuick.Effects
import QtQuick.Dialogs
import "components"
import "dialogs"
import "tabs"

Window {
    id: mainWin

    // ============================================================
    // 窗口尺寸按屏幕自适应
    // ------------------------------------------------------------
    // 原来写死 1600x1020 —— 在 1280x800（200% 缩放）这类逻辑分辨率小的机器上
    // **窗口比屏幕还大**，四面都出界。改成按屏幕可用区等比缩：
    //   · 大屏：被 1.0 封顶 → 就按设计基准 1600x1020，与原来一致
    //   · 小屏：按可用区缩到放得下，四边留 6% 余量
    // 用 desktopAvailable*（已扣任务栏）而不是 width/height（含任务栏），
    // 否则窗口底边会被任务栏压住。
    // ============================================================
    readonly property int designW: 1600
    readonly property int designH: 1020

    readonly property real fitRatio: Math.min(1.0,
        (Screen.desktopAvailableWidth  * 0.94) / designW,
        (Screen.desktopAvailableHeight * 0.94) / designH)

    width: Math.round(designW * fitRatio)
    height: Math.round(designH * fitRatio)
    // 最小尺寸按**设计的最小尺寸等比缩**（不是取当前尺寸！）。
    // ⚠️ 踩过的坑：写成 Math.min(1100, width) / Math.min(750, height) 时，
    //    小屏上（本机 fitRatio=0.70）最小值会等于当前尺寸 —— minimumHeight 变成 714
    //    而当前高度就是 714 → **窗口根本缩不小**，一拖毫无反应，看着像缩放功能整个坏了。
    //    设计基准里最小值是 1100x750（占设计尺寸 68.75% / 73.5%），等比缩放才保持同样的收缩余量。
    minimumWidth: Math.round(1100 * fitRatio)
    minimumHeight: Math.round(750 * fitRatio)

    // 启动时在可用区居中 —— 见下面那个（唯一的）Component.onCompleted。
    // ⚠️ QML 不允许同一个对象有两个 Component.onCompleted（会报
    //    "Property value set multiple times" 直接加载失败），所以居中并进那一个里。

    // Win10 才需要给"改窗口几何"的操作节流（拖动 + 拉边）：Win10 的 acrylic 每改一次
    // 窗口几何就重算整窗模糊。由 main.py 注入（见 _needs_throttle）；
    // 测试脚手架（_snap.py 等）不注入 → 用 typeof 兜底成 false，不会抛异常。
    readonly property bool throttleResize: (typeof glassThrottle !== 'undefined') && glassThrottle

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
            // 走 Python 的节流拖动（穿透模式）；自绘模式内部会退回 startSystemMove。
            // 不用 mainWin.startSystemMove() 直接拖：系统拖动把鼠标**每个输入事件**都变成一次
            // 窗口移动，Win10 的 acrylic 每步都要重模糊整窗 → DWM 饱和、窗体跟不上光标。
            // 节流到 DRAG_HZ(60) 次/秒后，模糊保住了，拖动也跟手。
            onPressed: glassDrag.start()
            onReleased: glassDrag.stop()   // 保险：不能只靠 Python 侧判松手
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
                // 不直接 showMinimized()：先让 QML 播"缩小 + 淡出"，播完由 Python 真正最小化
                // （透明的 layered 窗口没有系统最小化动画，直接最小化会"啪"地消失）
                onClicked: mainWin.minimizing = true
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

    // ============================================================
    // 最小化 / 还原的柔和过渡
    // ------------------------------------------------------------
    // 系统的窗口最小化动画**对透明（WS_EX_LAYERED）窗口不生效**，直接最小化就是"啪"地
    // 消失（像 PPT 的"出现"）。所以自己做：
    //   最小化：先把内容缩小 + 淡出，播完再由 Python 真正最小化
    //           （main.py 的 _MinimizeAnim 会拦下 SC_MINIMIZE，所以**点任务栏图标那条
    //             路径同样走这里**）
    //   还原：  窗口重新可见时反向播一遍
    // 缩放锚点是 contentItem 默认的 Center → "往窗口中心收"，观感接近 macOS。
    // ============================================================
    property bool minimizing: false
    onMinimizingChanged: if (minimizing) shrinkAnim.start()

    ParallelAnimation {
        id: shrinkAnim
        NumberAnimation { target: mainWin.contentItem; property: "scale"
                          to: 0.93; duration: 170; easing.type: Easing.InCubic }
        NumberAnimation { target: mainWin.contentItem; property: "opacity"
                          to: 0; duration: 170; easing.type: Easing.InCubic }
        onFinished: {
            // 先复位再交给系统：否则窗口下次出现时会停在缩小态
            mainWin.contentItem.scale = 1
            mainWin.contentItem.opacity = 1
            mainWin.minimizing = false
            glassWin.finishMinimize()
        }
    }
    ParallelAnimation {
        id: restoreAnim
        NumberAnimation { target: mainWin.contentItem; property: "scale"
                          from: 0.93; to: 1; duration: 210; easing.type: Easing.OutCubic }
        NumberAnimation { target: mainWin.contentItem; property: "opacity"
                          from: 0; to: 1; duration: 210; easing.type: Easing.OutCubic }
    }
    // 用形参接收，别用注入的 visibility（后者已废弃，会在 _run.log 里刷告警）
    onVisibilityChanged: (vis) => {
        if (vis !== Window.Minimized && vis !== Window.Hidden)
            restoreAnim.start()
    }

    // 页面交叉淡化调度：新页淡入与旧页淡出同时进行，避免切换"闪"。
    property var _pages: []
    property int _curPage: -1
    Component.onCompleted: {
        // 窗口在可用区居中。⚠️ **必须命令式赋值，不能写成 x:/y: 绑定** —— x 依赖 width，
        // 写成绑定后拉右边/下边改 width 会让绑定重算，窗口一边变宽一边被重新居中，整窗跟着漂。
        x = Math.round((Screen.desktopAvailableWidth - width) / 2)
        y = Math.round((Screen.desktopAvailableHeight - height) / 2)
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

    // 拉边节流（仅 Win10）：原来 onPositionChanged **每个鼠标事件**都改一次窗口几何。
    // Win10 的 acrylic 每改一次就要重算整窗模糊，1000Hz 鼠标 = 每秒 1000 次 → DWM 饱和、
    // 窗口跟不上手（与拖动同一个根因，见 main.py 的 _needs_throttle）。
    // 改成"只记最新鼠标位置、按 60Hz 一次性应用"，几何变更从约 1000 次/秒压到 60 次/秒。
    // Win11 走另一条合成路径没这个毛病 → throttleResize=false，保持逐事件原样。
    property string _rsMode: ""
    property real _rsLastX: 0
    property real _rsLastY: 0

    Timer {
        id: resizeThrottle
        interval: Math.max(8, Math.round(1000 / 60))
        repeat: true
        running: mainWin.throttleResize && mainWin._rsMode !== ""
        onTriggered: mainWin._resizeApply(mainWin._rsMode, mainWin._rsLastX, mainWin._rsLastY)
    }

    function _resizeBegin(mx, my) {
        _rsw = mainWin.width; _rsh = mainWin.height
        _rsx = mainWin.x; _rsy = mainWin.y
        _rsmx = mx; _rsmy = my
        _rsMode = ""
    }
    function _resizeApply(mode, mx, my) {
        var dx = mx - _rsmx
        var dy = my - _rsmy
        if (mode.indexOf("L") >= 0) { mainWin.x = _rsx + dx; mainWin.width = Math.max(mainWin.minimumWidth, _rsw - dx) }
        if (mode.indexOf("R") >= 0) { mainWin.width = Math.max(mainWin.minimumWidth, _rsw + dx) }
        if (mode.indexOf("T") >= 0) { mainWin.y = _rsy + dy; mainWin.height = Math.max(mainWin.minimumHeight, _rsh - dy) }
        if (mode.indexOf("B") >= 0) { mainWin.height = Math.max(mainWin.minimumHeight, _rsh + dy) }
    }
    // 拖动中：节流开启时只记最新位置，交给 Timer 按帧应用；关闭时逐事件（原行为）
    function _resizeDrag(mode, mx, my) {
        if (!throttleResize) { _resizeApply(mode, mx, my); return }
        _rsMode = mode; _rsLastX = mx; _rsLastY = my
    }
    // 松手：把最后一帧补上（鼠标最后一小段移动可能还没被 Timer 应用），再停表
    function _resizeEnd() {
        if (throttleResize && _rsMode !== "") _resizeApply(_rsMode, _rsLastX, _rsLastY)
        _rsMode = ""
    }

    // ⚠️ 对角光标别写反：Qt 的 F=Forward=「\」(↖↘)、B=Backward=「/」(↗↙)。
    //    规律是**左上/右下同向（\）、右上/左下同向（/）**。
    //    原来左上角写成了 B、右上角写成了 F —— 两处互换，所以左上角显示「/」、
    //    右上角显示「\」，全是反的（左下/右下是对的）。
    MouseArea { x: mainWin.width - 5; y: 5; width: 5; height: mainWin.height - 10; cursorShape: Qt.SizeHorCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("R", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: 5; y: mainWin.height - 5; width: mainWin.width - 10; height: 5; cursorShape: Qt.SizeVerCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("B", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: mainWin.width - 5; y: mainWin.height - 5; width: 5; height: 5; cursorShape: Qt.SizeFDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("RB", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: 0; y: mainWin.height - 5; width: 8; height: 5; cursorShape: Qt.SizeBDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("LB", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: 0; y: 5; width: 5; height: mainWin.height - 10; cursorShape: Qt.SizeHorCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("L", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: 5; y: 0; width: mainWin.width - 10; height: 5; cursorShape: Qt.SizeVerCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("T", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: mainWin.width - 5; y: 0; width: 5; height: 8; cursorShape: Qt.SizeBDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("TR", mouse.x, mouse.y); onReleased: _resizeEnd() }
    MouseArea { x: 0; y: 0; width: 8; height: 8; cursorShape: Qt.SizeFDiagCursor
        onPressed: _resizeBegin(mouse.x, mouse.y)
        onPositionChanged: _resizeDrag("LT", mouse.x, mouse.y); onReleased: _resizeEnd() }
}
