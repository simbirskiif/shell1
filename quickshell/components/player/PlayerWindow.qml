import QtQuick
import Quickshell
import Quickshell.Wayland
import "../quick"
import "../settings"
import "../../singletons"

// Окно плеера: обложка, трек, управление, перемотка и живой спектр.
// Открывается иконкой плеера в баре; состояние — PlayerWindowState.
PanelWindow {
    id: root

    required property ShellScreen playerScreen

    readonly property string screenName: root.playerScreen ? root.playerScreen.name : ""
    readonly property bool requested: PlayerWindowState.opened
                                      && PlayerWindowState.screenName === root.screenName
    readonly property var player: SpectrumService.player
    readonly property bool hasPlayer: root.player !== null
    readonly property real progress: root.player && root.player.length > 0
                                     ? Math.max(0, Math.min(1, root.player.position / root.player.length))
                                     : 0
    readonly property bool canSeek: root.player !== null && root.player.canSeek
                                    && root.player.positionSupported

    screen: playerScreen
    visible: root.requested
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

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: PlayerWindowState.close()
    }

    function formatTime(value) {
        const total = Math.max(0, Math.floor(Number(value) || 0));
        const minutes = Math.floor(total / 60);
        const seconds = total % 60;
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrimOverlay

        MouseArea {
            anchors.fill: parent
            onClicked: PlayerWindowState.close()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.max(360, Math.min(480, parent.width - Theme.space.xxxl * 2))
        height: Math.max(360, Math.min(760, parent.height - Theme.space.xxxl * 2))
        radius: Theme.shape.xl
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xl
                anchors.verticalCenter: parent.verticalCenter
                text: "Плеер"
                color: Theme.scheme.onSurface
                font: Theme.typeTitleLarge
            }

            Item {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shape.full
                    color: closeHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
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
            id: content

            anchors.top: headerDivider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space.xl
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: contentColumn

                width: content.width
                spacing: Theme.space.lg

                // Обложка: скруглённый квадрат, при отсутствии арта —
                // тональная заглушка с ноткой.
                Rectangle {
                    width: Math.min(200, contentColumn.width)
                    height: width
                    x: (contentColumn.width - width) / 2
                    radius: Theme.shape.lg
                    color: Theme.surfaceContainerHighest
                    clip: true

                    Image {
                        id: cover

                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        visible: source !== "" && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 440
                        sourceSize.height: 440
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || !root.player.trackArtUrl
                                 || cover.status !== Image.Ready
                        text: "\uf001"
                        color: Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 44
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.space.xs

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Без названия")
                                          : "Ничего не играет"
                        color: Theme.scheme.onSurface
                        font: Theme.typeTitleLarge
                        horizontalAlignment: Text.AlignHCenter
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
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: root.player && (root.player.trackAlbum || "") !== ""
                        text: root.player ? root.player.trackAlbum : ""
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodySmall
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
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
                            if (root.canSeek && root.player.length > 0)
                                root.player.position = value * root.player.length;
                        }
                    }

                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            text: root.player ? root.formatTime(root.player.position) : "0:00"
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

                Column {
                    width: parent.width
                    spacing: Theme.space.sm

                    SettingsSwitchRow {
                        title: "Спектр"
                        description: "Реальный анализ аудиопотока (parec + БПФ)"
                        checked: SpectrumService.enabled
                        onToggled: SpectrumService.enabled = !SpectrumService.enabled
                    }

                    SpectrumBars {
                        width: parent.width
                        height: 76
                        bands: SpectrumService.bands
                        bars: 24
                        gap: 3
                        minBarHeight: 2
                        barColor: Theme.primary
                        visible: SpectrumService.enabled
                    }
                }
            }
        }
    }

    // Кнопка управления плеером в стиле M3.
    component PlayerControl: Item {
        id: control

        property string icon: ""
        property bool primary: false
        property bool enabled: true

        signal clicked()

        width: control.primary ? 56 : 44
        height: width
        opacity: control.enabled ? 1 : Theme.disabledContent

        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: control.primary ? Theme.primary : "transparent"
            border.width: control.primary ? 0 : 1
            border.color: Theme.outlineVariant
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
