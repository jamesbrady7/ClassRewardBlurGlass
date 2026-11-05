import QtQuick
import "components"

// 启动动画：一个**透明底**的悬浮球（与课堂快捷悬浮球里的球完全同款）。
// 自动播一次「点击」：四芒星放大回弹 + 四圈四芒星涟漪。
// 图层顺序也与悬浮球一致：球色 → 涟漪 → 白色四芒星；
// 涟漪由 34→45px 渐变遮罩柔和裁切（与悬浮球当前效果完全同步）。
Window {
    id: win

    visible: true
    color: "transparent"
    flags: Qt.SplashScreen | Qt.FramelessWindowHint
           | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    width: 240; height: 240
    // 用当前屏幕的虚拟原点/尺寸居中（与主界面一致；desktopAvailableHeight 在多屏时是虚拟桌面高度）
    x: Math.round(Screen.virtualX + (Screen.width - width) / 2)
    y: Math.round(Screen.virtualY + (Screen.height - height) / 2)
    title: "班级激励助手"

    // Python 在主界面准备就绪后置 true（此时才开始点击动画）
    property bool startRipple: false
    signal finished()

    onStartRippleChanged: if (startRipple) clickAnim.start()

    // 窗口是透明的，但 240×240 区域仍会接收鼠标；启动期间吞掉点击
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }

    Item {
        id: stage
        anchors.fill: parent

        // ── 球：与 FloatBall.qml 的 ballItem 完全同尺寸/同配色 ──
        Item {
            id: ballItem
            width: 100; height: 100
            anchors.centerIn: parent

            IridescentFill {
                anchors.fill: parent
                circle: true            // 真圆
                fade: 0.26              // 边缘向外渐隐
                scheme: "marine"
                opacity: 0.62           // 半透明，与悬浮球一致
            }
        }

        // ── 涟漪：在球色**之上**、星芒之下；由 34→45px 渐变遮罩裁切 ──
        Canvas {
            id: ripple
            anchors.centerIn: parent
            width: 240; height: 240
            property real progress: 0
            onProgressChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                if (progress <= 0.001 || progress >= 0.999) return
                c.lineJoin = "round"
                c.lineCap = "round"
                var cx = width / 2, cy = height / 2

                // 用四芒星原路径当模板（24×24 坐标系里中心到顶点 = 8.4），按半径 s 缩放描边
                function starPath(cc, x, y, s) {
                    var u = s / 8.4
                    cc.beginPath()
                    cc.moveTo(x, y - 8.4 * u)
                    cc.quadraticCurveTo(x + 1 * u, y - 1 * u, x + 8.4 * u, y)
                    cc.quadraticCurveTo(x + 1 * u, y + 1 * u, x, y + 8.4 * u)
                    cc.quadraticCurveTo(x - 1 * u, y + 1 * u, x - 8.4 * u, y)
                    cc.quadraticCurveTo(x - 1 * u, y - 1 * u, x, y - 8.4 * u)
                    cc.closePath()
                }

                // [延迟, 单圈时长, 亮度系数, 最远半径, 扩散曲线指数, 淡出指数]
                // 与 FloatBall 的 sparkRipple 完全同一组参数
                var rings = [
                    [0.00, 0.78, 0.90, 100, 0.65, 0.40],
                    [0.24, 0.66, 0.72, 96, 0.58, 0.40],
                    [0.44, 0.54, 0.56, 62, 0.62, 1.50],
                    [0.60, 0.36, 0.33, 48, 0.60, 1.50]
                ]
                for (var i = 0; i < rings.length; i++) {
                    var d = rings[i][0], dur = rings[i][1], k = rings[i][2]
                    var rMax = rings[i][3], expo = rings[i][4], fade = rings[i][5]
                    var t = Math.max(0, Math.min(1, (progress - d) / dur))
                    if (t <= 0 || t >= 1) continue
                    var r = 2 + (rMax - 2) * Math.pow(t, expo)
                    var a = 0.65 * Math.pow(1 - t, fade) * k
                    if (a <= 0.002) continue
                    starPath(c, cx, cy, r)
                    var layers = [[1.8, 0.95], [3.4, 0.55], [5.6, 0.30],
                                  [8.4, 0.14], [11.5, 0.05]]
                    // 极淡暗边：浅色桌面上也能看出星形轮廓
                    c.strokeStyle = "rgba(18,24,40," + (a * 0.12).toFixed(3) + ")"
                    c.lineWidth = 3.6
                    c.stroke()
                    for (var j = 0; j < layers.length; j++) {
                        c.strokeStyle = "rgba(255,255,255,"
                                        + (a * layers[j][1]).toFixed(3) + ")"
                        c.lineWidth = layers[j][0]
                        c.stroke()
                    }
                }

                // 视觉遮罩：34px 以内实心，34→45px 柔和渐隐，45px 外擦掉
                // （与 FloatBall 的 sparkRipple 完全同一组参数）
                c.globalCompositeOperation = "destination-in"
                var mg = c.createRadialGradient(cx, cy, 0, cx, cy, 45)
                mg.addColorStop(0, "rgba(0,0,0,1)")
                mg.addColorStop(0.7556, "rgba(0,0,0,1)")       // 34px：仍是实心
                mg.addColorStop(0.8333, "rgba(0,0,0,0.75)")    // 37.5px
                mg.addColorStop(0.9111, "rgba(0,0,0,0.36)")    // 41px
                mg.addColorStop(0.9667, "rgba(0,0,0,0.12)")    // 43.5px
                mg.addColorStop(1, "rgba(0,0,0,0)")            // 45px：完全消失
                c.fillStyle = mg
                c.fillRect(0, 0, width, height)
                c.globalCompositeOperation = "source-over"
            }
        }

        // ── 白色四芒星：最上层；点击时放大回弹 ──
        Item {
            id: sparkleWrap
            anchors.centerIn: parent
            width: 54; height: 54

            Item {
                id: sparkClick
                anchors.fill: parent
                CanvasIcon {
                    anchors.fill: parent
                    name: "sparkle"
                    color: "#ffffff"
                }
            }
        }
    }

    // 点击时间线：四芒星 120% → 三段递减回弹（与悬浮球一致）+ 1.4s 涟漪
    SequentialAnimation {
        id: clickAnim

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: sparkClick; property: "scale"
                    to: 1.20; duration: 110; easing.type: Easing.OutCubic
                }
                NumberAnimation { target: sparkClick; property: "scale"; to: 1.13; duration: 105; easing.type: Easing.InOutSine }
                NumberAnimation { target: sparkClick; property: "scale"; to: 0.92; duration: 115; easing.type: Easing.InOutSine }
                NumberAnimation { target: sparkClick; property: "scale"; to: 1.06; duration: 105; easing.type: Easing.InOutSine }
                NumberAnimation { target: sparkClick; property: "scale"; to: 0.97; duration: 95; easing.type: Easing.InOutSine }
                NumberAnimation { target: sparkClick; property: "scale"; to: 1.02; duration: 85; easing.type: Easing.InOutSine }
                NumberAnimation { target: sparkClick; property: "scale"; to: 1.00; duration: 75; easing.type: Easing.InOutSine }
            }
            NumberAnimation {
                target: ripple; property: "progress"
                from: 0; to: 1; duration: 1400; easing.type: Easing.Linear
            }
        }

        // 先通知 Python 准备主界面（主窗以 opacity=0 显示并渲染），
        // 然后球再淡出——两边有一段交叉，不会出现"球没了、主窗还没出来"的空档。
        ScriptAction { script: win.finished() }
        NumberAnimation {
            target: stage; property: "opacity"
            from: 1; to: 0; duration: 180; easing.type: Easing.InCubic
        }
    }
}
