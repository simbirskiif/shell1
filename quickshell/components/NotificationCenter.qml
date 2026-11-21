import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
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

    // Видимость ведём сами: окно должно успеть проявиться и сжаться,
    // прежде чем исчезнуть.
    property bool shown: false
    property bool closing: false

    // Кнопка-иконка M3: круг 40dp; включённое состояние — tonal-контейнер
    // secondaryContainer, обычное — только state layer при наведении.
    component PanelIconButton: Item {
        id: button

        property string icon: ""
        property bool active: false

        signal clicked()

        width: Theme.iconButtonSize
        height: Theme.iconButtonSize

        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: button.active ? Theme.secondaryContainer
                                 : (buttonHover.containsMouse && button.enabled
                                    ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                    : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.active ? Theme.scheme.onSecondaryContainer
                                 : (button.enabled
                                    ? Theme.scheme.onSurface
                                    : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent))
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        MouseArea {
            id: buttonHover

            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

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

    // Карточка панели: M3-лист на surfaceContainerLow (панельная роль темы —
    // тот же тон с лёгкой вуалью над обоями), радиус xl.
    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + Theme.space.xs
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        width: Theme.notificationCenterWidth
        height: Math.min(layout.implicitHeight + Theme.notificationPadding * 2, root.maxHeight)
        radius: Theme.shape.xl
        color: Theme.panelSurface
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true

        // Появление и закрытие — как у остальных панелей: проявление с 92%
        // и рост из верхнего правого угла.
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

            // Шапка M3 top app bar: заголовок titleLarge, справа — круглые
            // кнопки-иконки 40 и текстовая кнопка «Очистить».
            Item {
                id: header

                width: parent.width
                height: Theme.appBarHeight

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.sm
                    anchors.right: headerActions.left
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Уведомления"
                    color: Theme.scheme.onSurface
                    font: Theme.typeTitleLarge
                    elide: Text.ElideRight
                }

                Row {
                    id: headerActions

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xs

                    // Тот же «не беспокоить», что и плиткой в быстрых настройках.
                    PanelIconButton {
                        icon: NotificationService.doNotDisturb ? "\uf1f6" : "\uf0f3"
                        active: NotificationService.doNotDisturb
                        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                    }

                    // «Очистить» — текстовая кнопка M3: прозрачный контейнер,
                    // подпись labelLarge цветом primary, state layer, а в
                    // disabled — 38% контента.
                    Item {
                        id: clearButton

                        width: clearLabel.implicitWidth + Theme.space.xl
                        height: Theme.buttonHeight
                        enabled: NotificationService.history.count > 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.shape.full
                            color: clearHover.containsMouse && clearButton.enabled
                                   ? Theme.stateLayer(Theme.primary, Theme.stateHover)
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            id: clearLabel

                            anchors.centerIn: parent
                            text: "Очистить"
                            color: clearButton.enabled
                                   ? Theme.primary
                                   : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContent)
                            font: Theme.typeLabelLarge
                            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                        }

                        MouseArea {
                            id: clearHover

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: clearButton.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.clearHistory()
                        }
                    }

                    PanelIconButton {
                        icon: "\uf00d"
                        onClicked: NotificationService.closeCenter()
                    }
                }
            }

            // Пустой Центр: иконка и заголовок headlineSmall на onSurfaceVariant.
            Item {
                width: parent.width
                height: NotificationService.history.count === 0 ? 130 : 0
                visible: height > 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.space.sm

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\uf0f3"
                        color: Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.xl
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Нет уведомлений"
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeHeadlineSmall
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
