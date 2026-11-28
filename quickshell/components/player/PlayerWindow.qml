import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../effects"
import "../expressive"
import "../../singletons"

// Панель плеера в стиле Material 3 Expressive.
//
// Слой blur обложки — отдельный большой источник (1.5× карточки), который
// обрезается ClippingRectangle карточки: так на углах нет пустых сэмплов и
// тёмной кромки. Рамка карточки рисуется поверх blur и контента.
PanelWindow {
    id: root

    required property ShellScreen playerScreen

    readonly property string screenName: root.playerScreen ? root.playerScreen.name : ""
    readonly property bool requested: PlayerWindowState.opened
                                      && PlayerWindowState.screenName === root.screenName
    readonly property var player: SpectrumService.player
    readonly property bool hasPlayer: root.player !== null
    readonly property bool canSeek: root.player !== null && root.player.canSeek
                                    && root.player.positionSupported
    readonly property real progress: root.player && root.player.length > 0
                                     ? Math.max(0, Math.min(1,
                                           root.displayPosition / root.player.length))
                                     : 0
    readonly property real maxHeight: root.playerScreen
                                      ? root.playerScreen.height - Theme.barHeight - Theme.space.lg
                                      : 700
    readonly property real panelRadius: Theme.shape.xlIncreased

    // Появление/закрытие — пружинами, без линейных кривых.
    property bool shown: false
    property bool closing: false

    // Позиция MPRIS приходит редко; между событиями дорисовываем её по часам,
    // а на positionChanged снова привязываемся к реальной позиции.
    property real displayPosition: 0
    property real anchorPosition: 0
    property double anchorWall: 0

    // Динамическая палитра из обложки.
    readonly property string artUrl: root.player ? (root.player.trackArtUrl || "") : ""
    readonly property bool hasArt: root.artUrl !== "" && artSource.status === Image.Ready
    property color artSeed: Theme.primary
    readonly property color artPrimary: root.hasArt
                                        ? Theme.toneColor(root.artSeed, 80, 0.62)
                                        : Theme.primary
    readonly property color artOnPrimary: root.hasArt
                                          ? Theme.toneColor(root.artSeed, 20, 0.62)
                                          : Theme.scheme.onPrimary
    readonly property color artPrimaryContainer: root.hasArt
                                                 ? Theme.toneColor(root.artSeed, 30, 0.62)
                                                 : Theme.primaryContainer
    readonly property color artOnPrimaryContainer: root.hasArt
                                                   ? Theme.toneColor(root.artSeed, 90, 0.62)
                                                   : Theme.scheme.onPrimaryContainer
    readonly property color artSecondaryContainer: root.hasArt
                                                   ? Theme.toneColor(root.artSeed, 30, 0.30)
                                                   : Theme.secondaryContainer
    readonly property color artOnSecondaryContainer: root.hasArt
                                                     ? Theme.toneColor(root.artSeed, 90, 0.30)
                                                     : Theme.scheme.onSecondaryContainer
    readonly property color artSurface: root.hasArt
                                        ? Theme.toneColor(root.artSeed, 8, 0.10)
                                        : Theme.surfaceContainerLow
    readonly property color artOnSurface: root.hasArt
                                          ? Theme.toneColor(root.artSeed, 92, 0.10)
                                          : Theme.scheme.onSurface
    readonly property color artOnSurfaceVariant: root.hasArt
                                                 ? Theme.toneColor(root.artSeed, 78, 0.16)
                                                 : Theme.scheme.onSurfaceVariant

    screen: playerScreen
    visible: root.shown || root.closing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-player"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive
                                              : WlrKeyboardFocus.None
    WlrLayershell.focusable: root.visible

    // Композиторный blur нужен только в пустом состоянии: когда есть арт,
    // его место занимает собственный Kawase-слой внутри карточки.
    BackgroundEffect.blurRegion: (root.shown && !root.closing && !artBackdrop.visible)
                                 ? playerBlurRegion : null
    AnimatedBlurRegion {
        id: playerBlurRegion
        target: card
        cornerRadius: Math.max(0, card.radius - card.border.width)
    }

    // Выбор цвета из обложки. ColorQuantizer не читает удалённые URL
    // (обложки MPRIS часто приходят с https), поэтому берём средневзвешенный
    // цвет через Canvas — тот же приём, что в виджете музыки.
    Canvas {
        id: artSampler

        x: -64
        y: -64
        width: 24
        height: 24
        opacity: 0.01

        property string src: root.artUrl
        property string loaded: ""

        function refresh() {
            if (loaded !== "" && loaded !== src)
                unloadImage(loaded);
            loaded = "";
            root.artSeed = Theme.primary;
            if (src === "")
                return;
            if (isImageLoaded(src)) {
                loaded = src;
                requestPaint();
            } else {
                loadImage(src);
            }
        }

        onSrcChanged: refresh()
        Component.onCompleted: refresh()

        onImageLoaded: {
            if (src !== "" && isImageLoaded(src)) {
                loaded = src;
                requestPaint();
            }
        }

        onPaint: {
            if (loaded === "" || loaded !== src)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(src, 0, 0, width, height);
            const data = ctx.getImageData(0, 0, width, height).data;
            let red = 0, green = 0, blue = 0, weight = 0;
            for (let i = 0; i < data.length; i += 4) {
                const r = data[i] / 255;
                const g = data[i + 1] / 255;
                const b = data[i + 2] / 255;
                const max = Math.max(r, g, b);
                const min = Math.min(r, g, b);
                if (max < 0.10)
                    continue;
                const saturation = (max - min) / max;
                const w = 0.02 + saturation * saturation * max;
                red += r * w;
                green += g * w;
                blue += b * w;
                weight += w;
            }
            if (weight > 0) {
                const sampled = Qt.rgba(red / weight, green / weight, blue / weight, 1);
                if (Theme.saturationOf(sampled) > 0.05
                        || Theme.relativeLuminance(sampled) > 0.05)
                    root.artSeed = sampled;
            } else {
                root.artSeed = Theme.primary;
            }
        }
    }

    // Смена трека: лёгкое проявление обложки и текста на пружине, без
    // линейных анимаций.
    function flashTrack() {
        if (!coverHost || !info)
            return;
        coverHost.opacity = 0.45;
        coverHost.scale = 0.96;
        info.opacity = 0.45;
        trackAppear.restart();
    }

    function appear() {
        closeTimer.stop();
        root.closing = false;
        root.shown = true;
    }

    function disappear() {
        if (!root.shown && !root.closing)
            return;
        root.shown = false;
        root.closing = true;
        closeTimer.restart();
    }

    function syncVisibility() {
        if (root.requested)
            root.appear();
        else
            root.disappear();
    }

    Component.onCompleted: root.syncVisibility()

    Connections {
        target: PlayerWindowState

        function onOpenedChanged() {
            root.syncVisibility();
        }

        function onScreenNameChanged() {
            root.syncVisibility();
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.motionMedium2
        repeat: false
        onTriggered: {
            root.closing = false;
            root.shown = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: PlayerWindowState.close()
    }

    function syncPosition() {
        if (!root.player) {
            root.displayPosition = 0;
            root.anchorPosition = 0;
            root.anchorWall = 0;
            return;
        }
        const position = Number(root.player.position) || 0;
        root.anchorPosition = position;
        root.anchorWall = Date.now();
        root.displayPosition = position;
    }

    function formatTime(value) {
        const total = Math.max(0, Math.floor(Number(value) || 0));
        const minutes = Math.floor(total / 60);
        const seconds = total % 60;
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    onPlayerChanged: root.syncPosition()
    onVisibleChanged: if (root.visible) root.syncPosition()

    Connections {
        target: root.player

        function onPositionChanged() {
            root.syncPosition();
        }

        function onTrackChanged() {
            root.syncPosition();
            root.flashTrack();
        }

        function onPlaybackStateChanged() {
            root.syncPosition();
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying
        onTriggered: {
            if (!root.player)
                return;
            let position = root.anchorPosition + (Date.now() - root.anchorWall) / 1000;
            if (root.player.length > 0)
                position = Math.min(root.player.length, position);
            root.displayPosition = Math.max(0, position);
        }
    }

    ParallelAnimation {
        id: trackAppear

        SpringAnimation {
            target: coverHost
            property: "opacity"
            to: 1
            spring: Theme.springs.effects.spring
            damping: Theme.springs.effects.damping
            epsilon: 0.001
        }
        SpringAnimation {
            target: coverHost
            property: "scale"
            to: 1
            spring: Theme.springs.spatialFast.spring
            damping: Theme.springs.spatialFast.damping
            epsilon: 0.001
        }
        SpringAnimation {
            target: info
            property: "opacity"
            to: 1
            spring: Theme.springs.effects.spring
            damping: Theme.springs.effects.damping
            epsilon: 0.001
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown && !root.closing
        onClicked: PlayerWindowState.close()
    }

    ClippingRectangle {
        id: card

        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + Theme.space.xs
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        width: Math.min(Theme.notificationCenterWidth, parent.width - Theme.space.xl * 2)
        height: Math.min(root.maxHeight,
                         Math.max(180, header.height + 1 + Theme.notificationPadding * 2
                                  + contentColumn.implicitHeight))
        radius: root.panelRadius
        color: root.hasArt
               ? Theme.withAlpha(root.artSurface, 0.96)
               : Theme.panelBlurSurface
        border.width: 1
        border.color: Theme.withAlpha(root.artOnSurfaceVariant, 0.24)
        contentInsideBorder: false

        opacity: root.shown && !root.closing ? 1 : 0
        scale: root.shown && !root.closing ? 1 : Theme.motionFadeThroughScale
        transformOrigin: Item.TopRight

        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatial {} }
        Behavior on height { SpringSpatial {} }

        // Внутренний ClippingRectangle обрезает blur на радиус
        // «внешний − толщина рамки», поэтому артефактов на углах нет.
        ClippingRectangle {
            id: artLayer

            anchors.fill: parent
            anchors.margins: card.border.width
            radius: Math.max(0, card.radius - card.border.width)
            color: "transparent"
            contentInsideBorder: false

            Item {
                id: artBackdrop

                anchors.centerIn: parent
                width: parent.width * 1.5
                height: parent.height * 1.5
                visible: root.hasArt

                Image {
                    id: artSource

                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: Math.max(1, Math.round(width / 2))
                    sourceSize.height: Math.max(1, Math.round(height / 2))
                    visible: false
                }

                ShaderEffectSource {
                    id: artTexture

                    sourceItem: artSource
                    width: Math.max(1, artSource.width)
                    height: Math.max(1, artSource.height)
                    hideSource: true
                    live: root.visible
                    visible: false
                }

                KawaseBlur {
                    anchors.fill: parent
                    sourceItem: artTexture
                    live: root.visible
                    blurRadius: Theme.blurRadius(64)
                    tint: root.artSurface
                    tintOpacity: Math.min(0.84, Theme.artTintOpacity + 0.04)
                    saturation: 1.2
                    cornerRadius: 0
                }
            }
        }
        // Тонкий scrim поверх blur: текст должен оставаться читаемым
        // на светлых обложках, но blur не должен спорить с контентом.
        Rectangle {
            anchors.fill: parent
            color: root.artSurface
            opacity: root.hasArt ? 0.10 : 0
            visible: root.hasArt
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.touchTarget

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xl
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("settings.player.title")
                color: root.artOnSurfaceVariant
                font: Theme.typeLabelLarge
                elide: Text.ElideRight
            }

            Item {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shape.full
                    color: closeHover.containsMouse
                           ? Theme.stateLayer(root.artOnSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: root.artOnSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize.lg
                }

                MouseArea {
                    id: closeHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PlayerWindowState.close()
                }
            }
        }

        Rectangle {
            id: headerDivider

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.withAlpha(root.artOnSurfaceVariant, 0.18)
        }

        Flickable {
            id: scroller

            anchors.top: headerDivider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.notificationPadding
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: contentColumn

                width: scroller.width
                spacing: Theme.notificationSpacing

                Item {
                    width: parent.width
                    height: Math.max(104, info.implicitHeight)

                    Item {
                        id: coverHost

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 104
                        height: 104

                        ClippingRectangle {
                            anchors.fill: parent
                            visible: root.hasArt
                            radius: Theme.shape.xl
                            color: root.artPrimaryContainer

                            Image {
                                anchors.fill: parent
                                source: root.artUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 208
                                sourceSize.height: 208
                            }
                        }

                        MorphShape {
                            anchors.fill: parent
                            visible: !root.hasArt
                            shape: "cookie"
                            modulation: 0.55
                            color: root.artPrimaryContainer
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.hasArt
                            text: "\uf001"
                            color: root.artOnPrimaryContainer
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 38
                        }
                    }

                    Column {
                        id: info

                        anchors.left: coverHost.right
                        anchors.leftMargin: Theme.space.lg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.xs

                        Text {
                            width: parent.width
                            text: root.player
                                  ? (root.player.trackTitle || I18n.tr("player.untitled"))
                                  : I18n.tr("player.nothingPlaying")
                            color: root.artOnSurface
                            font: root.hasPlayer
                                  ? Theme.typeEmphasizedTitleLarge
                                  : Theme.typeEmphasizedTitleMedium
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.player
                                  ? (root.player.trackArtist || I18n.tr("player.unknownArtist"))
                                  : I18n.tr("player.startMpris")
                            color: root.artOnSurfaceVariant
                            font: Theme.typeBodyMedium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: root.player && (root.player.trackAlbum || "") !== ""
                            text: root.player ? root.player.trackAlbum : ""
                            color: root.artOnSurfaceVariant
                            opacity: 0.82
                            font: Theme.typeBodySmall
                            elide: Text.ElideRight
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.space.xs
                    visible: root.hasPlayer

                    WavyProgress {
                        width: parent.width
                        value: root.progress
                        playing: root.player !== null && root.player.isPlaying
                        enabled: root.canSeek
                        activeColor: root.artPrimary
                        trackColor: Theme.withAlpha(root.artOnSurfaceVariant, 0.30)
                        onMoved: value => {
                            if (root.canSeek && root.player.length > 0) {
                                const target = value * root.player.length;
                                root.player.position = target;
                                root.anchorPosition = target;
                                root.anchorWall = Date.now();
                                root.displayPosition = target;
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            text: root.player ? root.formatTime(root.displayPosition) : "0:00"
                            color: root.artOnSurfaceVariant
                            font: Theme.typeLabelMedium
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.player ? root.formatTime(root.player.length) : "0:00"
                            color: root.artOnSurfaceVariant
                            font: Theme.typeLabelMedium
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.space.lg
                    visible: root.hasPlayer

                    PlayerSideControl {
                        icon: "\uf048"
                        enabled: root.player && root.player.canGoPrevious
                        baseColor: root.artSecondaryContainer
                        inkColor: root.artOnSecondaryContainer
                        onClicked: if (root.player) root.player.previous()
                    }

                    PlayerPlayControl {
                        playing: root.player !== null && root.player.isPlaying
                        enabled: root.player && root.player.canTogglePlaying
                        baseColor: root.artPrimary
                        inkColor: root.artOnPrimary
                        onClicked: if (root.player) root.player.togglePlaying()
                    }

                    PlayerSideControl {
                        icon: "\uf051"
                        enabled: root.player && root.player.canGoNext
                        baseColor: root.artSecondaryContainer
                        inkColor: root.artOnSecondaryContainer
                        onClicked: if (root.player) root.player.next()
                    }
                }

                /*
                 * Спектр в самой панели отключён: он живёт в иконке бара
                 * и настраивается в разделе «Плеер» окна настроек.
                 * Код оставлен, чтобы можно было вернуть большие полосы.
                 *
                 * SpectrumBars {
                 *     width: parent.width
                 *     height: 64
                 *     bands: SpectrumService.bands
                 *     bars: 20
                 *     gap: 3
                 *     minBarHeight: 2
                 *     barColor: Theme.primary
                 * }
                 */
            }
        }
    }

}
