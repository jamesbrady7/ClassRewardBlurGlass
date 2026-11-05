import QtQuick
import QtQuick.Effects
import QtQuick.Dialogs
import Qt.labs.platform 1.1 as Platform
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

    // ⚠️ 这里必须用**当前屏幕**的 Screen.width/height，不能用 desktopAvailableWidth/Height：
    //    后者在多显示器环境下是**整个虚拟桌面**的尺寸（本机实测 3640，而主屏只有 2560），
    //    拿它算窗口大小/居中会把主窗放到虚拟桌面的中点 → 学校双屏/投影场景下会严重偏位。
    //    高度用 0.88 给任务栏留余量（宽度 0.94）。
    readonly property real fitRatio: Math.min(1.0,
        (Screen.width  * 0.94) / designW,
        (Screen.height * 0.88) / designH)

    // 首次真正 show 时再用当时的屏幕校正一次（QML 加载时 Window 可能还没落到目标屏）。
    property bool _firstShown: false

    // 以**当前屏幕**的虚拟原点 + 当前屏尺寸居中（多屏时 x/y 是虚拟桌面坐标）。
    function centerMain() {
        var sx = Screen.virtualX
        var sy = Screen.virtualY
        x = Math.round(sx + (Screen.width - width) / 2)
        y = Math.round(sy + (Screen.height - height) / 2)
        console.log("[main] center -> x=" + x + " y=" + y
                    + " " + Math.round(width) + "x" + Math.round(height)
                    + " screen=" + Screen.name + " vx=" + sx + " vy=" + sy
                    + " sw=" + Screen.width + " sh=" + Screen.height)
    }

    // 只检查"标题栏是否还够得着"：窗口可以被用户放到边上，但不能整个飞出屏幕，
    // 否则就像之前那样只剩右下角、没有按钮可点、也无法拖动。
    function ensureTitleBarVisible() {
        var sx = Screen.virtualX
        var sy = Screen.virtualY
        var sw = Screen.width
        var sh = Screen.height
        var topOK = (y + 82 > sy) && (y < sy + sh - 40)
        var xOK = (x + width > sx + 120) && (x < sx + sw - 120)
        if (!topOK || !xOK) {
            console.log("[main] off-screen x=" + Math.round(x) + " y=" + Math.round(y)
                        + " " + Math.round(width) + "x" + Math.round(height)
                        + " -> recenter")
            centerMain()
        }
    }

    // 显示器布局变化（插拔投影、改缩放、跨屏）时，窗口可能被系统丢到屏幕外。
    // 等属性绑定（新屏幕的 width/height）结算完再检查，避免用旧尺寸误判。
    Connections {
        target: Screen
        function onWidthChanged() { Qt.callLater(mainWin.ensureTitleBarVisible) }
        function onHeightChanged() { Qt.callLater(mainWin.ensureTitleBarVisible) }
        function onVirtualXChanged() { Qt.callLater(mainWin.ensureTitleBarVisible) }
        function onVirtualYChanged() { Qt.callLater(mainWin.ensureTitleBarVisible) }
    }

    width: Math.round(designW * fitRatio)
    height: Math.round(designH * fitRatio)
    // 固定小值，不要再乘 fitRatio：屏幕切换时 QML 属性绑定求值顺序不保证 ——
    // 实测从主屏移到 150% 副屏后，width 跟随 fitRatio 变成 677，但 height 被
    // **旧屏幕的 minimumHeight=750** 卡住（新 fit 高度本应 431），跨屏后尺寸就不对。
    // 固定 min 同时保证小屏/竖屏能缩到 fit 尺寸。
    minimumWidth: 700
    minimumHeight: 450

    // 启动时在可用区居中 —— 见下面那个（唯一的）Component.onCompleted。
    // ⚠️ QML 不允许同一个对象有两个 Component.onCompleted（会报
    //    "Property value set multiple times" 直接加载失败），所以居中并进那一个里。

    // Win10 才需要给"改窗口几何"的操作节流（拖动 + 拉边）：Win10 的 acrylic 每改一次
    // 窗口几何就重算整窗模糊。由 main.py 注入（见 _needs_throttle）；
    // 测试脚手架（_snap.py 等）不注入 → 用 typeof 兜底成 false，不会抛异常。
    readonly property bool throttleResize: (typeof glassThrottle !== 'undefined') && glassThrottle

    // 启动时先由 qml/Splash.qml 的悬浮球动画遮住，主窗在动画期间于背后渲染，
    // 动画淡出后再露出来（避免先看到一个"只有模糊底、还没画内容"的空窗）。
    // 测试/截图脚本加载后需要自己 show()。
    visible: false
    title: "班级激励助手"
    color: "transparent"
    // 无边框，标题栏自绘以统一风格。
    // ⚠️ 必须带上 Minimize/MaximizeButtonHint：只有 FramelessWindowHint 时窗口样式是
    //    WS_POPUP，**WS_MINIMIZEBOX / WS_MAXIMIZEBOX 都会丢**。而 Windows 的 DefWindowProc
    //    处理 SC_RESTORE / SC_MAXIMIZE 时要检查这两个位 —— 没有它们，**点任务栏按钮
    //    还原不了已最小化的窗口**（应用自己的最小化按钮走 ShowWindow 直通，所以那个是好的，
    //    很容易误判成"最小化没问题"）。这两个 hint 不会加回边框，窗口仍然无边框。
    flags: Qt.Window | Qt.FramelessWindowHint
           | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint

    // 关闭主窗口（标题栏 × / Alt+F4）先确认；确认后把 forceClose 置 true 再真正关。
    // 悬浮球里的「退出」走 QGuiApplication.quit()，不经过这里（那边已经确认过了）。
    property bool forceClose: false
    onClosing: function(close) {
        if (forceClose) return
        close.accepted = false
        dlgConfirmBox.openConfirm("退出软件",
            "确定要退出吗？\n退出后可安全拔出 U 盘。", function() {
            forceClose = true
            // 走统一退出入口：关闭悬浮球/启动页 + 结束事件循环（不再只 close 主窗，
            // 否则隐藏的悬浮球窗口可能让进程继续占着 U 盘上的 exe）
            appControl.quitApp()
        }, "退出")
    }

    // ── 系统托盘图标（通知区域）──────────────────────────────────
    // 这就是 Steam / QQ 那种小图标：主界面隐藏、只剩悬浮球时它仍在，
    // 随时可以右键「彻底退出」，避免进程残留占着 U 盘。
    function trayShowMain() {
        try {
            if (typeof floatBridge !== 'undefined' && floatBridge)
                floatBridge.showMain()
        } catch (e) {}
        mainWin.showNormal()
        mainWin.show()
        // 即使主窗已经可见但飞出了屏幕，托盘「打开主界面」也要能把它拉回来
        mainWin.ensureTitleBarVisible()
        mainWin.raise()
        mainWin.requestActivate()
    }
    function trayEnterFloat() {
        try {
            if (typeof floatBridge !== 'undefined' && floatBridge)
                floatBridge.enterFloatMode()
            else
                toastBox.show("悬浮球暂不可用", 2000, true)
        } catch (e) {
            toastBox.show("悬浮球暂不可用", 2000, true)
        }
    }

    Platform.SystemTrayIcon {
        id: trayIcon
        visible: true
        tooltip: "班级激励助手"
        icon.source: Qt.resolvedUrl("../assets/app_icon.png")
        menu: Platform.Menu {
            Platform.MenuItem { text: "打开主界面"; onTriggered: trayShowMain() }
            Platform.MenuItem { text: "进入悬浮球"; onTriggered: trayEnterFloat() }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: "彻底退出"; onTriggered: appControl.quitApp() }
        }
        // 单击 / 双击 → 回到主界面；右键由 menu 自己处理
        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger
                    || reason === Platform.SystemTrayIcon.DoubleClick)
                trayShowMain()
        }
        Component.onCompleted: console.log("[tray] available=" + available
                                           + " trigger=" + Platform.SystemTrayIcon.Trigger)
    }

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
    // 今日分数截图预览（独立置顶小窗，历史页的「保存今日分数截图」打开它）
    property alias scorePreview: scorePreviewWin

    // ============================================================
    // 共享计时器（主界面「工具箱」↔ 悬浮球）
    // ------------------------------------------------------------
    // 全进程只有一个实例：工具箱直接读写它；悬浮球是同一进程里的**另一个 QML
    // 根对象**，看不到这里的 id，所以 main.py 在加载悬浮球之前把本对象注册成
    // context property "timerHub" 交过去。两边因此始终是同一份状态——
    // 在主界面开始倒计时、切进悬浮球照样在走，反过来也一样。
    // ============================================================
    property QtObject timerHub: timerHubObj
    TimerHub { id: timerHubObj }

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
        // ── tint 必须按模式分档 ───────────────────────────────
        // 穿透模式：DWM 已经在窗后糊化桌面了，面板再叠 80% 白（默认 #ccffffff）
        //   就是一条**实心白带** —— 实测标题栏 alpha=204(80%)、紧挨着它的下方 alpha=0，
        //   差 80 个点，所以看着特别突兀。
        //   降到 35% 让桌面透过来（再低文字在深色壁纸上会不好认）。
        // 自绘模式：面板自己模糊 captured 的背景，80% 白是当初配好的，**不动**。
        tint: systemGlass ? Theme.titleTintGlass : Theme.titleTint

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            // 统一走 Python 自绘拖动（按屏幕光标绝对位移，Win10 / Win11 同一套）。
            // 不用 startSystemMove 直接拖：系统拖动把鼠标**每个输入事件**都变成一次
            // 窗口移动，Win10 的 acrylic 每步都要重模糊整窗 → DWM 饱和、窗体跟不上光标。
            // 节流到 DRAG_HZ(60) 次/秒后，模糊保住了，拖动也跟手。
            // ⚠️ 不能把 QCursor 交给 Python：一体机触摸时 QCursor 是旧鼠标位置。
            // 把 MouseArea 点击点映射到屏幕坐标；窗口移动后局部坐标会反向补偿，
            // 两者相加始终等于真实触点 → 鼠标和手指都能保持点击时的绝对位置。
            onPressed: function(m) {
                var p = mapToItem(null, m.x, m.y)
                glassDrag.startAt(mainWin.x + p.x, mainWin.y + p.y)
            }
            onPositionChanged: function(m) {
                if (!pressed) return
                var p = mapToItem(null, m.x, m.y)
                glassDrag.moveTo(mainWin.x + p.x, mainWin.y + p.y)
            }
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
            // 昼夜切换已移到界面左下角（与「进入悬浮球模式」并排）
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
                accent: true; scheme: "mintcyan"  // 加号：长条按钮 21 色（薄荷青绿）
                fg: "#ffffff"
                icon: "plus"
                hint: "新建班级"
                // 不要"悬停放大 + 图标加粗"的反馈；按下改为轻微变暗
                interactiveScale: false
                iconWeightOnHover: false
                pressDim: true
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
            titles: ["花名册", "小组榜", "随机抽取", "批量操作", "积分商店", "每日历史", "数据分析", "工具箱"]
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
            }

            // ===== 页面宿主（8 页，交叉淡化切换）=====
            Item {
                id: pageHost
                width: parent.width
                height: contentRow.height - (30 + Theme.spacing)   // 直接绑 id，避开 Column implicitHeight 循环
                clip: true

                // 页面级滚动：窗口缩小到内容放不下时，整页可上下滚动，滚动条为全站细圆角样式。
                PageScroll {
                    id: page0
                    anchors.fill: parent
                    visible: false; opacity: 1; z: 0
                    RosterTab { anchors.fill: parent }
                }
                // 小组榜本身就是 Flickable（内部滚动条见 GroupTab）
                GroupTab { id: page1; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                PageScroll {
                    id: page2
                    anchors.fill: parent
                    visible: false; opacity: 1; z: 0
                    RandomPickTab { anchors.fill: parent }
                }
                PageScroll {
                    id: page3
                    anchors.fill: parent
                    visible: false; opacity: 1; z: 0
                    BatchTab { anchors.fill: parent }
                }
                PageScroll {
                    id: page4
                    anchors.fill: parent
                    visible: false; opacity: 1; z: 0
                    ShopTab { anchors.fill: parent }
                }
                // 每日历史：列表自己滚动（不要再套 PageScroll，否则两层滚动条重叠）
                HistoryTab { id: page5; anchors.fill: parent; visible: false; opacity: 1; z: 0 }
                PageScroll {
                    id: page6
                    anchors.fill: parent
                    visible: false; opacity: 1; z: 0
                    AnalysisTab { anchors.fill: parent }
                }
                PageScroll {
                    id: page7
                    anchors.fill: parent
                    visible: false; opacity: 1; z: 0
                    ToolboxTab { anchors.fill: parent; hub: mainWin.timerHub }
                }
            }
        }
    }

    // ============================================================
    // 左下角：模式切换（昼夜 / 悬浮球）
    // ------------------------------------------------------------
    // 两个都是"整个界面换一种用法"的开关，放在常规导航之外的最左下角，
    // 不和页面内容混在一起。昼夜沿用原来标题栏那颗 CircleButton（太阳/月亮同位置切换）；
    // 悬浮球是"滑动进入"——按住小球从左往右拖到头才生效（见 components/SlideToFloat）。
    // 同一排的总宽被导航条锁死（180）：30 + 6 + 128 = 164，所以滑动条里的标签用 5 字
    // 「进入悬浮球」，才放得下右侧三个引导箭头。
    // ============================================================
    Row {
        id: modeSwitches
        // ⚠️ anchors 不能跨父级锚到 appTabs（QML 会静默忽略，元素跑到 (0,0)）。
        //    contentRow 距窗口左/下各 24（见上面 width: parent.width - 48 / bottomMargin: 24），
        //    这里加上它自己的 8 / 14，就落在左侧导航玻璃条内部的最左下角。
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 24 + 8
        anchors.bottomMargin: 24 + 14
        spacing: 6
        z: 5

        CircleButton {
            size: 30
            raised: true
            shadow: false
            icon: Theme.night ? "sun" : "moon"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Theme.toggleNight()
        }

        SlideToFloat {
            id: slideToFloat
            width: 128
            anchors.verticalCenter: parent.verticalCenter
            // 悬浮球模块没加载成功时（异常/裁剪过的构建）不动作——
            // 否则主界面一藏就再也回不来
            onActivated: {
                if (typeof floatBridge === 'undefined' || !floatBridge) return
                if (mainWin.enteringFloat) return
                // 先播"收向左下角"的退场动画，播完再由动画回调真正隐藏窗口
                mainWin.enteringFloat = true
            }
        }
    }

    // ============================================================
    // 进入悬浮球模式：主界面淡出再隐藏（不做收拢）
    // ------------------------------------------------------------
    // 直接 hide 是"啪"地消失；这里让 contentItem 淡出，播完才调
    // floatBridge.enterFloatMode()（主窗 hide + 球 show）。
    // 不做 scale 收拢：桌面穿透模式下 Acrylic 是窗口级的、不跟内容缩放，
    // 收拢时会在磨砂矩形里缩一下，观感反而怪。
    // 回来时复用下面的 restoreAnim（show() → visibilityChanged → 反向淡入）。
    // ============================================================
    property bool enteringFloat: false
    onEnteringFloatChanged: if (enteringFloat) collapseAnim.start()

    NumberAnimation {
        id: collapseAnim
        target: mainWin.contentItem
        property: "opacity"
        to: 0
        duration: 200
        // 退场用 ease-in：先平稳、末尾加速消失（和进场的 ease-out 成对）
        easing.type: Easing.InCubic
        onFinished: {
            if (typeof floatBridge !== 'undefined' && floatBridge)
                floatBridge.enterFloatMode()
            // 窗口已经藏起来了，这里复位看不到跳变；下次 show() 由 restoreAnim 反向播
            mainWin.contentItem.opacity = 1
            mainWin.enteringFloat = false
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
        if (vis === Window.Minimized || vis === Window.Hidden)
            return
        console.log("[main] visible vis=" + vis
                    + " x=" + Math.round(x) + " y=" + Math.round(y)
                    + " " + Math.round(width) + "x" + Math.round(height)
                    + " screen=" + Screen.name)
        if (!_firstShown) {
            // 首次上屏：用真正的屏幕尺寸/原点再居中一次
            _firstShown = true
            centerMain()
        } else {
            // 从悬浮球/最小化回来：如果主窗已经飞出屏幕，拉回屏幕中心
            ensureTitleBarVisible()
        }
        restoreAnim.start()
    }

    // 页面交叉淡化调度：新页淡入与旧页淡出同时进行，避免切换"闪"。
    property var _pages: []
    property int _curPage: -1
    Component.onCompleted: {
        // ⚠️ 必须命令式赋值，不能写成 x:/y: 绑定 —— x 依赖 width，
        //    写成绑定后拉右边/下边改 width 会让绑定重算，窗口一边变宽一边被重新居中，整窗跟着漂。
        centerMain()
        _pages = [page0, page1, page2, page3, page4, page5, page6, page7]
        showPage(0)
        // 首次 show() 时由 restoreAnim 从 0 淡入；先置 0，避免 show 的第一帧整窗闪一下
        mainWin.contentItem.opacity = 0
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
        if (i < 0 || i >= 8 || i === _curPage) return
        var prev = _curPage
        _curPage = i
        appTabs.currentIndex = i
        // 旧页立即收起（不淡出复现），避免"上一个 tab 闪一下"
        if (prev >= 0) { _pages[prev].visible = false; _pages[prev].z = 0; _pages[prev].opacity = 1 }
        // 新页快速淡入
        for (var k = 0; k < 8; k++) {
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
        color: Theme.surface
        border.color: Theme.border
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
                color: Theme.divider
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
        color: Theme.surface
        border.color: Theme.border
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
                color: Theme.divider
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

    // 今日分数截图预览窗（独立 Window；默认置顶，开关持久化）
    ScorePreviewWindow { id: scorePreviewWin }

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
    // 屏幕上光标的绝对起点（逻辑像素）。缩放必须用它，不能用 MouseArea 的局部坐标：
    // 左/上边缘拖动时窗口本身在移动，局部坐标会跟着窗口变 → 自己和自己的位移叠加，
    // 产生"甩飞/抖动"（与悬浮球缩放手柄同一个根因）。
    property real _rsCurX: 0
    property real _rsCurY: 0

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

    // 从 MouseArea 的触点拿到**屏幕逻辑坐标**（触摸/鼠标都可靠，不用 QCursor）
    // ⚠️ Qt 6 的 MouseArea **没有 `area.mouse` 属性**（那是 Qt 5 才有）→ 必须用信号参数 m.x/m.y。
    //    原来这里读 area.mouse.x 会抛 "Cannot read property 'x' of undefined"，
    //    症状就是主界面完全拉不动边（放大缩小失效）。
    function _resizeScreen(area, m) {
        var p = area.mapToItem(null, m.x, m.y)
        return Qt.point(mainWin.x + p.x, mainWin.y + p.y)
    }
    function _resizeBegin(mx, my) {
        _rsw = mainWin.width; _rsh = mainWin.height
        _rsx = mainWin.x; _rsy = mainWin.y
        _rsCurX = mx; _rsCurY = my
        _rsMode = ""
        console.log("[resize-main] start touch=" + mx + "," + my
                    + " win=" + _rsx + "," + _rsy + " " + _rsw + "x" + _rsh)
    }
    function _resizeApply(mode, mx, my) {
        var dx = mx - _rsCurX
        var dy = my - _rsCurY
        // 左/上边缘：先算新尺寸，再按"右/下边缘不动"反推 x/y。
        // 直接写 x=_rsx+dx 的话，宽度碰到最小值后右边缘还会继续跟着鼠标跑。
        if (mode.indexOf("L") >= 0) {
            var nw = Math.max(mainWin.minimumWidth, _rsw - dx)
            mainWin.width = nw
            mainWin.x = _rsx + (_rsw - nw)
        }
        if (mode.indexOf("R") >= 0) mainWin.width = Math.max(mainWin.minimumWidth, _rsw + dx)
        if (mode.indexOf("T") >= 0) {
            var nh = Math.max(mainWin.minimumHeight, _rsh - dy)
            mainWin.height = nh
            mainWin.y = _rsy + (_rsh - nh)
        }
        if (mode.indexOf("B") >= 0) mainWin.height = Math.max(mainWin.minimumHeight, _rsh + dy)
    }
    // 拖动中：节流开启时只记最新位置，交给 Timer 按帧应用；关闭时逐事件（原行为）
    function _resizeDrag(mode, mx, my) {
        if (!throttleResize) { _resizeApply(mode, mx, my); return }
        _rsMode = mode; _rsLastX = mx; _rsLastY = my
    }
    // 松手：把最后一帧补上（鼠标最后一小段移动可能还没被 Timer 应用），再停表
    function _resizeEnd() {
        if (throttleResize && _rsMode !== "") _resizeApply(_rsMode, _rsLastX, _rsLastY)
        console.log("[resize-main] end mode=" + _rsMode
                    + " win=" + Math.round(mainWin.x) + "," + Math.round(mainWin.y)
                    + " " + Math.round(mainWin.width) + "x" + Math.round(mainWin.height))
        _rsMode = ""
    }

    // ⚠️ 对角光标别写反：Qt 的 F=Forward=「\」(↖↘)、B=Backward=「/」(↗↙)。
    //    规律是**左上/右下同向（\）、右上/左下同向（/）**。
    //    原来左上角写成了 B、右上角写成了 F —— 两处互换，所以左上角显示「/」、
    //    右上角显示「\」，全是反的（左下/右下是对的）。
    // 触摸屏上 5px 很难按住 → 边缘加宽到 10px、四角 14px（页面本身有 24px 外边距，不会挡住内容）
    MouseArea { id: rzR; x: mainWin.width - 10; y: 10; width: 10; height: mainWin.height - 20; cursorShape: Qt.SizeHorCursor
        onPressed: function(m) { var p = _resizeScreen(rzR, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzR, m); _resizeDrag("R", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzB; x: 10; y: mainWin.height - 10; width: mainWin.width - 20; height: 10; cursorShape: Qt.SizeVerCursor
        onPressed: function(m) { var p = _resizeScreen(rzB, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzB, m); _resizeDrag("B", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzRB; x: mainWin.width - 14; y: mainWin.height - 14; width: 14; height: 14; cursorShape: Qt.SizeFDiagCursor
        onPressed: function(m) { var p = _resizeScreen(rzRB, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzRB, m); _resizeDrag("RB", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzLB; x: 0; y: mainWin.height - 14; width: 14; height: 14; cursorShape: Qt.SizeBDiagCursor
        onPressed: function(m) { var p = _resizeScreen(rzLB, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzLB, m); _resizeDrag("LB", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzL; x: 0; y: 10; width: 10; height: mainWin.height - 20; cursorShape: Qt.SizeHorCursor
        onPressed: function(m) { var p = _resizeScreen(rzL, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzL, m); _resizeDrag("L", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzT; x: 10; y: 0; width: mainWin.width - 20; height: 10; cursorShape: Qt.SizeVerCursor
        onPressed: function(m) { var p = _resizeScreen(rzT, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzT, m); _resizeDrag("T", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzTR; x: mainWin.width - 14; y: 0; width: 14; height: 14; cursorShape: Qt.SizeBDiagCursor
        onPressed: function(m) { var p = _resizeScreen(rzTR, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzTR, m); _resizeDrag("TR", p.x, p.y) }
        onReleased: _resizeEnd() }
    MouseArea { id: rzLT; x: 0; y: 0; width: 14; height: 14; cursorShape: Qt.SizeFDiagCursor
        onPressed: function(m) { var p = _resizeScreen(rzLT, m); _resizeBegin(p.x, p.y) }
        onPositionChanged: function(m) { var p = _resizeScreen(rzLT, m); _resizeDrag("LT", p.x, p.y) }
        onReleased: _resizeEnd() }
}
