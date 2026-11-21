import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "expressive"
import "../singletons"

// Центр уведомлений — такая же панель, как быстрые настройки: та же
// карточка, радиус, рамка и отступы, только с историей. Выезжает справа
// и уезжает туда же при закрытии.
PanelWindow {
    id: root

    required property ShellScreen centerScreen

    readonly property string screenName: root.centerScreen ? root.centerScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: root.focusedScreenName === ""
                                             || root.focusedScreenName === root.screenName
    readonly property real maxHeight: root.centerScreen
                                      ? root.centerScreen.height - Theme.barHeight - Theme.space.lg : 10000

    // Пустой Центр: большая клякса-форма, которая перетекает между
    // пресетами, пока истории нет. Состояние — только визуальное.
    property int emptyPhase: 0
    readonly property var emptyShapes: ["blob", "cookie", "clover", "sunny"]
    readonly property string emptyShape: root.emptyShapes[root.emptyPhase % root.emptyShapes.length]
    readonly property color emptyContainer: root.emptyPhase % 2 === 0
                                            ? Theme.primaryContainer : Theme.tertiaryContainer
    readonly property color emptyInk: root.emptyPhase % 2 === 0
                                      ? Theme.scheme.onPrimaryContainer
                                      : Theme.scheme.onTertiaryContainer

    Timer {
        interval: 1900
        repeat: true
        running: root.visible && NotificationService.history.count === 0
        onTriggered: root.emptyPhase += 1
    }

    // Видимость ведём сами: окно должно успеть проявиться и сжаться,
    // прежде чем исчезнуть.
    property bool shown: false
    property bool closing: false

    screen: centerScreen
    visible: (root.shown || root.closing) && root.onFocusedScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Connections {
        target: NotificationService

        function onCenterOpenChanged() {
            if (NotificationService.centerOpen)
                root.appear();
            else
                root.disappear();
        }
    }

    Component.onCompleted: if (NotificationService.centerOpen) root.appear()

    function appear() {
        closeTimer.stop();
        root.closing = false;
        root.shown = true;
    }

    function disappear() {
        if (!root.shown)
            return;
        // Сначала играет анимация сжатия, и только потом окно прячется.
        root.closing = true;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer

        interval: Theme.motionMedium1
        repeat: false
        onTriggered: {
            root.shown = false;
            root.closing = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: NotificationService.closeCenter()
    }

    // Клик мимо панели закрывает Центр.
    MouseArea {
        anchors.fill: parent
        onClicked: NotificationService.closeCenter()
    }

    // Карточка панели: Expressive-лист на панельной роли темы. Без
    // обводки: контейнер отделяется тоном и скруглением 32.
    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + Theme.space.xs
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        width: Theme.notificationCenterWidth
        height: Math.min(layout.implicitHeight + Theme.notificationPadding * 2, root.maxHeight)
        radius: Theme.shape.xlIncreased
        color: Theme.panelSurface
        clip: true

        // Появление и закрытие — пружины: проявление с 92% и рост из
        // верхнего правого угла; прозрачность — effects-пружина без
        // перелёта, чтобы панель не мигала на границе единицы.
        opacity: root.shown && !root.closing ? 1 : 0
        scale: root.shown && !root.closing ? 1 : Theme.motionFadeThroughScale
        transformOrigin: Item.TopRight

        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatial {} }

        // Клики по панели не должны закрывать её через подложку.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.notificationPadding
            spacing: Theme.notificationSpacing

            // Шапка Expressive: крупный заголовок headlineSmall; справа —
            // кнопка «не беспокоить», FAB очистки (tertiary, cookie) и
            // закрытие. Крупные тач-цели, без мелких иконок-точек.
            Item {
                id: header

                width: parent.width
                height: Theme.appBarHeight

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.xs
                    anchors.right: headerActions.left
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Уведомления"
                    color: Theme.scheme.onSurface
                    font: Theme.typeEmphasizedHeadlineSmall
                    elide: Text.ElideRight
                }

                Row {
                    id: headerActions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xs

                    // «Не беспокоить»: включённое состояние — форма cookie
                    // на secondaryContainer, как у колокольчика в баре.
                    Item {
                        id: dndButton

                        width: 48
                        height: 48
                        scale: dndHover.pressed ? 0.9 : (dndHover.containsMouse ? 1.05 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        MorphShape {
                            anchors.fill: parent
                            shape: NotificationService.doNotDisturb ? "cookie" : "circle"
                            modulation: 0.8
                            color: NotificationService.doNotDisturb
                                   ? Theme.secondaryContainer
                                   : (dndHover.containsMouse
                                      ? Theme.surfaceContainerHighest : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: NotificationService.doNotDisturb ? "\uf1f6" : "\uf0f3"
                            color: NotificationService.doNotDisturb
                                   ? Theme.scheme.onSecondaryContainer
                                   : Theme.scheme.onSurface
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.md
                        }

                        MouseArea {
                            id: dndHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                        }
                    }

                    // «Очистить» — ExpressiveFAB: крупная cookie в tertiary-
                    // контейнере. Пока истории нет — пригашен и не кликается.
                    ExpressiveFab {
                        id: clearFab

                        tone: "tertiary"
                        shape: "cookie"
                        hoverShape: "squircle"
                        size: 48
                        icon: "\uf1f8"
                        enabled: NotificationService.history.count > 0
                        opacity: clearFab.enabled ? 1 : 0.45
                        Behavior on opacity { SpringEffects {} }
                        onClicked: NotificationService.clearHistory()
                    }

                    Item {
                        id: closeButton

                        width: 48
                        height: 48
                        scale: closeHover.pressed ? 0.9 : (closeHover.containsMouse ? 1.05 : 1)
                        Behavior on scale { SpringSpatialFast {} }

                        MorphShape {
                            anchors.fill: parent
                            shape: closeHover.containsMouse ? "cookie" : "circle"
                            modulation: 0.8
                            color: closeHover.containsMouse
                                   ? Theme.surfaceContainerHighest : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            color: Theme.scheme.onSurface
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.md
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.closeCenter()
                        }
                    }
                }
            }

            // Пустой Центр: большая клякса, которая перетекает между
            // пресетами (blob → cookie → clover → sunny), и крупный
            // emphasized-заголовок. Вместо мелкой серой иконки — акцент.
            Item {
                width: parent.width
                height: NotificationService.history.count === 0 ? 212 : 0
                visible: height > 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.space.md

                    Item {
                        width: 120
                        height: 120
                        anchors.horizontalCenter: parent.horizontalCenter

                        MorphShape {
                            anchors.fill: parent
                            shape: root.emptyShape
                            color: root.emptyContainer
                            modulation: 0.85
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: NotificationService.doNotDisturb ? "\uf1f6" : "\uf0f3"
                            color: root.emptyInk
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 44
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Нет уведомлений"
                        color: Theme.scheme.onSurface
                        font: Theme.typeEmphasizedTitleLarge
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Здесь появятся новые сообщения"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                    }
                }
            }

            Flickable {
                id: flick

                width: parent.width
                visible: NotificationService.history.count > 0
                height: visible
                        ? Math.min(listColumn.implicitHeight,
                                   root.maxHeight - Theme.appBarHeight
                                   - Theme.notificationPadding * 2 - Theme.notificationSpacing)
                        : 0
                contentHeight: listColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Высота едет вместе с карточками и тем же таймингом, что у
                // остальных панелей: панель меняет размер с анимацией, а не
                // рывком, и карточки при этом не обрезаются.
                Behavior on height {
                    MotionNumber {
                        duration: Theme.motionMedium2
                        curve: Theme.curveEmphasized
                    }
                }

                Column {
                    id: listColumn

                    width: flick.width
                    spacing: Theme.notificationSpacing

                    Repeater {
                        model: NotificationService.history

                        delegate: NotificationCard {
                            required property var entry
                            required property int index

                            notification: entry
                            context: "center"
                            staggerIndex: index
                            width: listColumn.width
                        }
                    }
                }
            }
        }
    }}
