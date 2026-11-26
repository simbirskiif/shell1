import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../quick"
import "../../singletons"

// Панель плеера в стиле остальных панелей оболочки: правая карточка под
// баром, M3-строки, левое выравнивание текста, стандартные отступы и кнопки.
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

    // Появление/закрытие как у остальных панелей: карточка проявляется
    // и слегка масштабируется из правого верхнего угла.
    property bool shown: false
    property bool closing: false

    // Позиция MPRIS приходит редко; между событиями дорисовываем её по часам,
    // а на positionChanged снова привязываемся к реальной позиции.
    property real displayPosition: 0
    property real anchorPosition: 0
    property double anchorWall: 0

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
        interval: Theme.motionMedium1
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
        }

        function onPlaybackStateChanged() {
            root.syncPosition();
        }
    }

    Timer {
        interval: 250
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

    MouseArea {
        anchors.fill: parent
        enabled: root.shown && !root.closing
        onClicked: PlayerWindowState.close()
    }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + Theme.space.xs
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        width: Math.min(Theme.notificationCenterWidth, parent.width - Theme.space.xl * 2)
        height: Math.min(root.maxHeight,
                         Math.max(220, header.height + 1 + Theme.notificationPadding * 2
                                  + contentColumn.implicitHeight))
        radius: Theme.shape.xl
        color: Theme.panelSurface
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true
        opacity: root.shown && !root.closing ? 1 : 0
        scale: root.shown && !root.closing ? 1 : Theme.motionFadeThroughScale
        transformOrigin: Item.TopRight

        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on height {
            MotionNumber {
                duration: Theme.motionMedium2
                curve: Theme.curveEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.appBarHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xl
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                text: "Плеер"
                color: Theme.scheme.onSurface
                font: Theme.typeTitleLarge
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
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: Theme.scheme.onSurface
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
            color: Theme.outlineVariant
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

                // Строка «сейчас играет»: обложка слева, текст слева, как
                // строки остальных панелей. Без большого центрированного арта.
                Item {
                    width: parent.width
                    height: Math.max(88, info.implicitHeight)

                    Rectangle {
                        id: coverBox

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 88
                        height: 88
                        radius: Theme.shape.md
                        color: Theme.surfaceContainerHighest
                        clip: true

                        Image {
                            id: cover

                            anchors.fill: parent
                            source: root.player ? (root.player.trackArtUrl || "") : ""
                            visible: source !== "" && status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 176
                            sourceSize.height: 176
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.player || !root.player.trackArtUrl
                                     || cover.status !== Image.Ready
                            text: "\uf001"
                            color: Theme.scheme.onSurfaceVariant
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 30
                        }
                    }

                    Column {
                        id: info

                        anchors.left: coverBox.right
                        anchors.leftMargin: Theme.space.md
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.xs

                        Text {
                            width: parent.width
                            text: root.player ? (root.player.trackTitle || "Без названия")
                                              : "Ничего не играет"
                            color: Theme.scheme.onSurface
                            font: Theme.typeTitleMedium
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.player ? (root.player.trackArtist || "Неизвестный исполнитель")
                                              : "Запустите плеер с MPRIS"
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodyMedium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: root.player && (root.player.trackAlbum || "") !== ""
                            text: root.player ? root.player.trackAlbum : ""
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodySmall
                            elide: Text.ElideRight
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.space.xs
                    visible: root.hasPlayer

                    PanelSlider {
                        width: parent.width
                        value: root.progress
                        enabled: root.canSeek
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
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodySmall
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.player ? root.formatTime(root.player.length) : "0:00"
                            color: Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodySmall
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.space.lg
                    visible: root.hasPlayer

                    PlayerControl {
                        icon: "\uf048"
                        enabled: root.player && root.player.canGoPrevious
                        onClicked: if (root.player) root.player.previous()
                    }

                    PlayerControl {
                        icon: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                        primary: true
                        enabled: root.player && root.player.canTogglePlaying
                        onClicked: if (root.player) root.player.togglePlaying()
                    }

                    PlayerControl {
                        icon: "\uf051"
                        enabled: root.player && root.player.canGoNext
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

    // Кнопка управления плеером в стиле системных icon button: круг 40,
    // у play — primary-заливка. Без обводок, которых нет у других кнопок.
    component PlayerControl: Item {
        id: control

        property string icon: ""
        property bool primary: false
        property bool enabled: true

        signal clicked()

        width: control.primary ? 52 : Theme.iconButtonSize
        height: width
        opacity: control.enabled ? 1 : Theme.disabledContent

        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: control.primary ? Theme.primary : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: Theme.stateLayer(control.primary ? Theme.scheme.onPrimary
                                                    : Theme.scheme.onSurface,
                                    Theme.stateHover)
            opacity: hover.containsMouse && control.enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            anchors.centerIn: parent
            text: control.icon
            color: control.primary ? Theme.scheme.onPrimary : Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: control.primary ? Theme.iconSize.lg : Theme.iconSize.md
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            enabled: control.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }
}
