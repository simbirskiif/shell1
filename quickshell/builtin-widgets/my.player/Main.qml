import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris

Item {
    id: root
    required property var ctx

    // ───────────────────────── Данные плеера ─────────────────────────
    // Активный плеер: играющий, иначе первый. В превью — демо без MPRIS.
    readonly property var player: {
        if (ctx.preview) return null
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) return list[i]
        return list.length > 0 ? list[0] : null
    }
    readonly property bool hasPlayer: ctx.preview || player !== null
    readonly property bool playing: ctx.preview ? true : (player ? player.isPlaying : false)
    readonly property string title: ctx.preview ? "Название трека"
        : (player ? (player.trackTitle || "Без названия") : "Ничего не играет")
    readonly property string artist: ctx.preview ? "Исполнитель"
        : (player ? player.trackArtist : "Запустите музыку")
    readonly property string artUrl: (!ctx.preview && player) ? (player.trackArtUrl || "") : ""
    readonly property bool interactive: !ctx.editing && !ctx.preview && player !== null

    // ───────────────────────── Геометрия ─────────────────────────
    // Радиус карточки задаёт материал shell (≈ 0.28 клетки). Если у вас иначе — правится здесь.
    readonly property real cardRadiusFactor: 0.28
    readonly property real cardRadius: Math.round(ctx.cell * cardRadiusFactor)
    readonly property int pad: Math.max(6, Math.round(ctx.cell * 0.1))
    // Обложка вписана «по концентрической дуге»: радиус карточки минус отступ до границы
    readonly property real artRadius: Math.max(Math.round(ctx.dp * 4), cardRadius - pad)
    readonly property int btn: Math.max(26, Math.round(ctx.dp * 32))
    readonly property real innerW: width - 2 * pad
    readonly property real innerH: height - 2 * pad
    readonly property bool showArt: ctx.settings.showArt !== false

    // stack — почти квадрат (2x2): обложка сверху, кнопки по центру;
    // mini — узкая плашка (1x2): без обложки; wide — обложка слева.
    readonly property string layoutMode: width < height * 1.4 ? "stack"
        : (ctx.cols <= 2 ? "mini" : "wide")
    readonly property bool centered: layoutMode !== "wide"
    readonly property bool artVisible: showArt && layoutMode !== "mini"
    readonly property real artSide: layoutMode === "stack"
        ? Math.min(innerW, innerH * 0.5)
        : Math.min(innerH, innerW * 0.42)

    // ───────────────────────── Цвет обложки и градиент ─────────────────────────
    // Пока обложка не прочитана (и в превью) берём роль палитры: акцентный
    // tonal-контейнер или нейтральную поверхность, а не произвольный hex.
    property color sampledBase: ctx.colors.surfaceVariant
    property bool coverReady: false
    readonly property color baseColor: ctx.preview ? ctx.colors.primaryContainer
                                                   : sampledBase
    readonly property color topColor: Qt.hsva(Math.max(0, baseColor.hsvHue),
                                              baseColor.hsvSaturation * 0.85,
                                              Math.min(1, baseColor.hsvValue + 0.14), 1)
    // Анимированные цвета градиента (смена обложки → плавный переход)
    property color gradBottom: baseColor
    property color gradTop: topColor
    Behavior on gradBottom { ColorAnimation { duration: 700; easing.type: Easing.InOutQuad } }
    Behavior on gradTop { ColorAnimation { duration: 700; easing.type: Easing.InOutQuad } }

    // В нейтральном режиме фон карточки — градиент из обложки. Это
    // осознанное оформление плеера; прозрачный материал не отменяет его.
    readonly property bool transparentMode: ctx.material === "transparent"
    readonly property bool gradientOn: ctx.colorMode === "neutral"
                                       && (ctx.preview || coverReady)

    function applySample(r, g, b) {
        const col = Qt.rgba(r, g, b, 1)
        const s0 = col.hsvSaturation
        const s = s0 < 0.12 ? s0 : Math.min(0.85, Math.max(0.3, s0))   // серые обложки остаются серыми
        const v = Math.min(0.78, Math.max(0.42, col.hsvValue))
        sampledBase = Qt.hsva(Math.max(0, col.hsvHue), s, v, 1)
        coverReady = true
    }

    // ───────────────────────── Читаемость ─────────────────────────
    readonly property color cWhite: "#ffffff"
    readonly property color cDark: "#15161a"
    readonly property color surfaceC: (ctx.colors && ctx.colors.surface) ? ctx.colors.surface : "#151519"
    readonly property color onSurfaceC: (ctx.colors && ctx.colors.onSurface) ? ctx.colors.onSurface : "#ffffff"
    readonly property color primaryC: (ctx.colors && ctx.colors.primary) ? ctx.colors.primary : "#6750A4"

    function lum(c) {
        function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }
    function contrast(a, b) {
        const l1 = lum(a), l2 = lum(b)
        return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
    }
    function bestOn(bg) {
        return contrast(cWhite, bg) >= contrast(cDark, bg) ? cWhite : cDark
    }

    // Оценка фона под виджетом: середина градиента или поверхность системной палитры.
    // Если фон материала на деле светлее/темнее — менять нужно только эту строку.
    readonly property color bgC: gradientOn
        ? Qt.rgba((gradTop.r + gradBottom.r) / 2, (gradTop.g + gradBottom.g) / 2,
                  (gradTop.b + gradBottom.b) / 2, 1)
        : surfaceC

    // Есть собственный градиент — все цвета выбираем сами от него.
    // Нет градиента — цвета приходят от shell: для прозрачного материала
    // это ctx.backdrop (проба обоев), иначе ctx.colors.
    readonly property bool useBackdropInk: !gradientOn && transparentMode
                                           && !!ctx.backdrop
    property color fg: gradientOn ? bestOn(bgC)
        : (useBackdropInk ? ctx.backdrop.ink
        : (contrast(onSurfaceC, bgC) >= 4.5 ? onSurfaceC : bestOn(bgC)))
    property color fgDim: gradientOn ? Qt.alpha(fg, 0.72)
        : (useBackdropInk ? ctx.backdrop.inkMuted : Qt.alpha(fg, 0.72))
    property color toggleFill: gradientOn ? fg
        : (contrast(primaryC, bgC) >= 3 ? primaryC : fg)
    property color toggleIconColor: bestOn(toggleFill)
    Behavior on fg { ColorAnimation { duration: 300 } }
    Behavior on fgDim { ColorAnimation { duration: 300 } }
    Behavior on toggleFill { ColorAnimation { duration: 300 } }
    Behavior on toggleIconColor { ColorAnimation { duration: 300 } }

    // ───────────────────────── Компоненты ─────────────────────────
    // Иконки (без иконочных шрифтов). toggle: progress 0 = «play», 1 = «pause», с морфингом.
    component Glyph: Canvas {
        property string kind: "toggle"   // prev | next | toggle
        property color tint: "white"
        property real progress: 0
        onTintChanged: requestPaint()
        onKindChanged: requestPaint()
        onProgressChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.clearRect(0, 0, width, height)
            c.fillStyle = tint
            const w = width, h = height
            function quad(p, t, q) {
                c.beginPath()
                for (let i = 0; i < 4; i++) {
                    const x = (p[i * 2] + (q[i * 2] - p[i * 2]) * t) * w
                    const y = (p[i * 2 + 1] + (q[i * 2 + 1] - p[i * 2 + 1]) * t) * h
                    if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
                }
                c.closePath(); c.fill()
            }
            if (kind === "toggle") {
                quad([.32, .20, .55, .35, .55, .65, .32, .80], progress, [.28, .22, .43, .22, .43, .78, .28, .78])
                quad([.55, .35, .78, .50, .78, .50, .55, .65], progress, [.57, .22, .72, .22, .72, .78, .57, .78])
            } else if (kind === "next") {
                c.beginPath()
                c.moveTo(w * .24, h * .26); c.lineTo(w * .64, h * .5); c.lineTo(w * .24, h * .74)
                c.closePath(); c.fill()
                c.fillRect(w * .68, h * .26, w * .09, h * .48)
            } else {
                c.beginPath()
                c.moveTo(w * .76, h * .26); c.lineTo(w * .36, h * .5); c.lineTo(w * .76, h * .74)
                c.closePath(); c.fill()
                c.fillRect(w * .23, h * .26, w * .09, h * .48)
            }
        }
    }

    component CtrlButton: Item {
        id: cb
        property string kind: "toggle"   // prev | next | toggle
        property real size: 32
        property color fg: "white"       // цвет иконки prev/next и подсветки
        property color fill: "white"     // заливка toggle
        property color fillIcon: "black"   // иконка на заливке
        property real progress: 0
        property bool active: true
        property real slide: 0
        signal clicked()

        width: size
        height: size
        opacity: active ? 1 : 0.3
        Behavior on opacity { NumberAnimation { duration: 200 } }
        scale: mouse.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on progress { NumberAnimation { duration: 260; easing.type: Easing.InOutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: cb.kind === "toggle" ? cb.fill : cb.fg
            opacity: cb.kind === "toggle" ? 1
                : (mouse.pressed ? 0.20 : (mouse.containsMouse && cb.active ? 0.10 : 0))
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Glyph {
            id: glyph
            width: cb.size * 0.8
            height: cb.size * 0.8
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: cb.slide
            kind: cb.kind
            tint: cb.kind === "toggle" ? cb.fillIcon : cb.fg
            progress: cb.progress
        }

        // Анимация «пропуска»: иконка уезжает по направлению и возвращается с другой стороны
        SequentialAnimation {
            id: skipAnim
            property real dist: cb.size * 0.3 * (cb.kind === "next" ? 1 : -1)
            ParallelAnimation {
                NumberAnimation { target: cb; property: "slide"; to: skipAnim.dist; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: glyph; property: "opacity"; to: 0; duration: 110 }
            }
            PropertyAction { target: cb; property: "slide"; value: -skipAnim.dist }
            ParallelAnimation {
                NumberAnimation { target: cb; property: "slide"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: glyph; property: "opacity"; to: 1; duration: 180 }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: cb.active
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (cb.kind !== "toggle") skipAnim.restart()
                cb.clicked()
            }
        }
    }

    // Анимация «нет плеера»: спокойно «дышащий» эквалайзер
    component IdleBars: Item {
        property color tint: "white"
        Row {
            anchors.centerIn: parent
            height: parent.height
            spacing: Math.round(parent.width * 0.07)
            Repeater {
                model: 4
                Item {
                    id: slot
                    width: Math.max(3, Math.round(parent.parent.width * 0.09))
                    height: parent.height
                    property real lvl: 0.18
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: Math.max(width, parent.height * 0.5 * slot.lvl * 2)
                        radius: width / 2
                        color: slot.parent.parent.tint
                    }
                    SequentialAnimation on lvl {
                        loops: Animation.Infinite
                        running: slot.visible
                        NumberAnimation { to: 0.5; duration: 900 + index * 170; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.12; duration: 1000 + index * 130; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ───────────────────────── Выборка цвета обложки ─────────────────────────
    Canvas {
        id: sampler
        x: -64; y: -64
        width: 24; height: 24
        opacity: 0.01
        property string src: root.artUrl
        property string loaded: ""

        function refresh() {
            if (loaded !== "" && loaded !== src) unloadImage(loaded)
            loaded = ""
            if (src === "") { root.coverReady = false; return }
            if (isImageLoaded(src)) { loaded = src; requestPaint() }
            else loadImage(src)
        }
        onSrcChanged: refresh()
        Component.onCompleted: refresh()
        onImageLoaded: {
            if (src !== "" && isImageLoaded(src)) { loaded = src; requestPaint() }
        }
        onPaint: {
            if (loaded === "" || loaded !== src) return
            const c = getContext("2d")
            c.clearRect(0, 0, width, height)
            c.drawImage(src, 0, 0, width, height)
            const d = c.getImageData(0, 0, width, height).data
            let r = 0, g = 0, b = 0, ws = 0
            for (let i = 0; i < d.length; i += 4) {
                const R = d[i] / 255, G = d[i + 1] / 255, B = d[i + 2] / 255
                const mx = Math.max(R, G, B), mn = Math.min(R, G, B)
                if (mx < 0.12) continue                       // почти чёрные пиксели
                const s = (mx - mn) / mx
                const w = 0.02 + s * s * mx                   // насыщенные и яркие весят больше
                r += R * w; g += G * w; b += B * w; ws += w
            }
            if (ws > 0) root.applySample(r / ws, g / ws, b / ws)
        }
    }

    // ───────────────────────── Фон-градиент (только нейтральный режим) ─────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        opacity: root.gradientOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.gradTop }
            GradientStop { position: 1.0; color: root.gradBottom }
        }
    }

    // ───────────────────────── Обложка ─────────────────────────
    Item {
        id: artBox
        visible: root.artVisible
        width: root.artSide
        height: root.artSide
        x: root.layoutMode === "stack" ? (root.width - width) / 2 : root.pad
        y: root.layoutMode === "stack" ? root.pad : root.pad + (root.innerH - height) / 2
        scale: (root.playing || !root.hasPlayer) ? 1 : 0.95
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Маска со скруглением (квадрат с радиусом = радиус карточки − отступ)
        Item {
            id: maskItem
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: root.artRadius; color: "black" }
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskItem
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle { anchors.fill: parent; color: Qt.alpha(root.fg, 0.14) }

            IdleBars {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: parent.height * 0.5
                visible: !root.hasPlayer
                tint: root.fgDim
            }
            Text {
                anchors.centerIn: parent
                visible: root.hasPlayer && art.opacity < 1
                text: "♪"
                color: root.fgDim
                font.family: root.ctx.fontFamily
                font.pixelSize: Math.round(artBox.width * 0.45)
            }
            Image {
                id: art
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Math.ceil(artBox.width * 2)
                sourceSize.height: Math.ceil(artBox.width * 2)
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 280 } }
            }
        }
    }

    // ───────────────────────── Текст и управление ─────────────────────────
    // Подложку не рисуем: shell уже проверил обои под карточкой и передал
    // контрастный ctx.backdrop.ink / inkMuted.

    Column {
        id: info
        readonly property real artRight: root.artVisible && root.layoutMode === "wide"
            ? root.pad + root.artSide + root.pad : root.pad
        x: artRight
        width: root.width - artRight - root.pad
        spacing: Math.round(root.ctx.dp * 3)
        y: {
            if (root.layoutMode === "stack") {
                const top = artBox.y + root.artSide
                const free = root.height - root.pad - top
                return top + Math.max(Math.round(root.pad * 0.3), (free - height) / 2)
            }
            return (root.height - height) / 2
        }

        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
            color: root.fg
            font.family: root.ctx.fontFamily
            font.bold: true
            font.pixelSize: Math.max(12, Math.round(root.ctx.dp * 15))
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.artist
            elide: Text.ElideRight
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
            color: root.fgDim
            font.family: root.ctx.fontFamily
            font.pixelSize: Math.max(10, Math.round(root.ctx.dp * 12))
        }

        Item {
            width: parent.width
            height: root.btn + Math.round(root.pad * 0.6)

            // В узкой плашке без обложки вместо кнопок показываем «спящий» эквалайзер
            IdleBars {
                visible: !root.hasPlayer && root.layoutMode === "mini"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: root.btn * 1.4
                height: root.btn
                tint: root.fgDim
            }

            Row {
                id: controls
                y: Math.round(root.pad * 0.6)
                x: root.centered ? (parent.width - width) / 2 : 0
                spacing: Math.round(root.ctx.dp * 8)
                opacity: (!root.hasPlayer && root.layoutMode === "mini") ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                CtrlButton {
                    kind: "prev"
                    size: root.btn
                    fg: root.fg
                    active: root.interactive && root.player.canGoPrevious
                    onClicked: root.player.previous()
                }
                CtrlButton {
                    kind: "toggle"
                    size: root.btn
                    fill: root.toggleFill
                    fillIcon: root.toggleIconColor
                    progress: root.playing ? 1 : 0
                    active: root.interactive && root.player.canTogglePlaying
                    onClicked: root.player.togglePlaying()
                }
                CtrlButton {
                    kind: "next"
                    size: root.btn
                    fg: root.fg
                    active: root.interactive && root.player.canGoNext
                    onClicked: root.player.next()
                }
            }
        }
    }
}
