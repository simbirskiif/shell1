import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "expressive"
import "../singletons"

// Alt+Tab: горизонтальная лента окон в духе Material 3 Expressive.
// Каждая карточка — контрастный тональный контейнер (primary/tertiary/
// secondary по кругу) и морфящаяся форма: выбранная становится клевером и
// переезжает на secondaryContainer. Выбор читается формой, цветом и крупным
// заголовком, а не тонкой рамкой.
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

    // Крупнее прежнего: заголовки окон читаются с расстояния, иконка — 52.
    readonly property int cardWidth: 150
    readonly property int cardHeight: 168
    // Запас под пружинный масштаб выбранной карточки, чтобы ListView её не
    // обрезал по вертикали.
    readonly property int cardOverflow: 16
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

    // Панель-лист Expressive: тональная поверхность без обводки,
    // крупное скругление 32.
    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: root.rowWidth + Theme.space.xxl
        height: column.implicitHeight + Theme.space.xxl
        radius: Theme.shape.xlIncreased
        color: Theme.panelSurface

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
                height: root.cardHeight + root.cardOverflow
                orientation: ListView.Horizontal
                spacing: root.cardSpacing
                model: WindowState.snapshot
                currentIndex: WindowState.index
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property bool selected: tile.index === WindowState.index
                    // Контейнеры идут по кругу: primary → tertiary → secondary.
                    readonly property int toneIndex: tile.index % 3
                    readonly property color baseContainer: tile.toneIndex === 0
                                                           ? Theme.primaryContainer
                                                           : tile.toneIndex === 1
                                                             ? Theme.tertiaryContainer
                                                             : Theme.secondaryContainer
                    readonly property color baseInk: tile.toneIndex === 0
                                                     ? Theme.scheme.onPrimaryContainer
                                                     : tile.toneIndex === 1
                                                       ? Theme.scheme.onTertiaryContainer
                                                       : Theme.scheme.onSecondaryContainer
                    // Выбранная — всегда secondaryContainer + clover.
                    readonly property color containerColor: tile.selected
                                                            ? Theme.secondaryContainer
                                                            : tile.baseContainer
                    readonly property color inkColor: tile.selected
                                                      ? Theme.scheme.onSecondaryContainer
                                                      : tile.baseInk

                    width: root.cardWidth
                    height: root.cardHeight + root.cardOverflow

                    Item {
                        id: tileCard

                        anchors.centerIn: parent
                        width: root.cardWidth
                        height: root.cardHeight
                        // Пружина на выбор: выбранная карточка слегка
                        // раздувается, нажатие — сжимает.
                        scale: tileHover.pressed ? 0.96
                               : tile.selected ? 1.04
                               : (tileHover.containsMouse ? 1.02 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        MorphShape {
                            anchors.fill: parent
                            // Выбор меняет форму: clover ↔ squircle. Смена
                            // shape в MorphShape сама играет на пружине.
                            shape: "squircle"
                            color: tile.containerColor
                            modulation: 0.45
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        // Слой состояния при наведении — той же формой, чтобы
                        // не вылезать за волнистый контур.
                        MorphShape {
                            anchors.fill: parent
                            shape: "squircle"
                            modulation: 0.45
                            color: Theme.withAlpha(tile.inkColor, Theme.stateHover)
                            opacity: tileHover.containsMouse && !tile.selected ? 1 : 0
                            Behavior on opacity { SpringEffects {} }
                        }

                        // Иконка в орбе: у выбранной — «печенье», у остальных —
                        // круг. Орб тоже меняет форму, поэтому выбор виден
                        // даже по силуэту.
                        Item {
                            id: iconOrb

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 16
                            width: 64
                            height: 64

                            MorphShape {
                                anchors.fill: parent
                                shape: tile.selected ? "cookie" : "circle"
                                color: Theme.withAlpha(tile.inkColor, 0.14)
                                modulation: 0.85
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                source: root.iconFor(tile.modelData.appClass, tile.modelData.title)
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: iconOrb.bottom
                            anchors.topMargin: Theme.space.sm
                            anchors.leftMargin: Theme.space.sm
                            anchors.rightMargin: Theme.space.sm
                            spacing: 2

                            Text {
                                width: parent.width
                                height: 44
                                text: tile.modelData.title
                                color: tile.inkColor
                                // Крупный emphasized-заголовок вместо titleSmall.
                                font: Theme.typeEmphasizedTitleMedium
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: tile.modelData.appClass
                                color: Theme.withAlpha(tile.inkColor, 0.8)
                                font: Theme.typeLabelMedium
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: tileHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                WindowState.index = tile.index;
                                WindowState.release();
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: WindowState.snapshot.length === 0
                text: "Нет открытых окон"
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeEmphasizedTitleMedium
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
