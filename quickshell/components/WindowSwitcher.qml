import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../singletons"

// Alt+Tab: горизонтальная лента окон с иконками, как в Windows.
// Состояние и ввод — WindowState + GlobalShortcut (shell.qml).
// Клавиатурный фокус не забираем: иначе compositor перестанет
// присылать release Alt и chord развалится.
PanelWindow {
    id: root

    required property ShellScreen pickerScreen

    readonly property string screenName: pickerScreen ? pickerScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: focusedScreenName === ""
                                             || focusedScreenName === root.screenName

    readonly property int cardWidth: 136
    readonly property int cardHeight: 148
    readonly property int cardSpacing: 10
    readonly property int maxRowWidth: pickerScreen ? pickerScreen.width - 140 : 1000
    readonly property int rowWidth: Math.min(root.maxRowWidth,
        Math.max(1, WindowState.snapshot.length) * (root.cardWidth + root.cardSpacing)
        - root.cardSpacing)

    screen: pickerScreen
    visible: WindowState.shown && root.onFocusedScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-window-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function iconFor(appClass, title) {
        let entry = DesktopEntries.heuristicLookup(appClass);
        if (!entry && title)
            entry = DesktopEntries.heuristicLookup(title);
        const iconName = entry && entry.icon ? entry.icon : appClass;
        const found = Quickshell.iconPath(iconName, true);
        return found !== "" ? found : Quickshell.iconPath("application-x-executable", true);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WindowState.cancel()
    }

    // Панель-лист M3: тональная поверхность container-low под карточки,
    // радиус xl, обводка outline-variant.
    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: root.rowWidth + Theme.space.xxl
        height: column.implicitHeight + Theme.space.xxl
        radius: Theme.shape.xl
        color: Theme.panelSurface
        border.width: 1
        border.color: Theme.outlineVariant

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.space.lg
            spacing: Theme.space.sm

            ListView {
                id: list

                width: parent.width
                height: root.cardHeight
                orientation: ListView.Horizontal
                spacing: root.cardSpacing
                model: WindowState.snapshot
                currentIndex: WindowState.index
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property bool selected: tile.index === WindowState.index

                    width: root.cardWidth
                    height: root.cardHeight
                    // Карточки M3: тональный surfaceContainerHigh, выбранная —
                    // secondaryContainer с текстом onSecondaryContainer.
                    radius: Theme.shape.lg
                    color: tile.selected ? Theme.secondaryContainer
                                         : Theme.surfaceContainerHigh

                    HoverHandler {
                        id: hover
                    }

                    // Слой состояния M3 при наведении — поверх тона, под текстом.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(tile.selected
                                                ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurface,
                                                Theme.stateHover)
                        opacity: hover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            WindowState.index = tile.index;
                            WindowState.release();
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.space.sm
                        spacing: Theme.space.sm

                        Item {
                            width: 52
                            height: 52
                            anchors.horizontalCenter: parent.horizontalCenter

                            Image {
                                anchors.fill: parent
                                source: root.iconFor(tile.modelData.appClass, tile.modelData.title)
                                sourceSize: Qt.size(52, 52)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        Text {
                            width: parent.width
                            height: 40
                            text: tile.modelData.title
                            color: tile.selected ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurface
                            font: Theme.typeTitleSmall
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: tile.modelData.appClass
                            color: tile.selected
                                   ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.8)
                                   : Theme.scheme.onSurfaceVariant
                            font: Theme.typeBodySmall
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: WindowState.snapshot.length === 0
                text: I18n.tr("switcher.noWindows")
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: WindowState.lastError !== ""
                text: WindowState.lastError
                color: Theme.error
                font: Theme.typeBodySmall
                wrapMode: Text.Wrap
            }
        }
    }
}
