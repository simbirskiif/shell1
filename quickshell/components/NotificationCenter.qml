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
                                      ? root.centerScreen.height - Theme.barHeight - 16 : 10000

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

    // Карточка панели: те же токены темы, что у остальных панелей.
    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + 4
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        width: Theme.quickWidth
        height: Math.min(layout.implicitHeight + Theme.quickPadding * 2, root.maxHeight)
        radius: Theme.quickRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder
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
            anchors.margins: Theme.quickPadding
            spacing: Theme.notificationSpacing

            Item {
                id: header

                width: parent.width
                height: Theme.quickHeaderHeight

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Уведомления"
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Тот же «не беспокоить», что и плиткой в быстрых настройках.
                    PanelIconButton {
                        icon: NotificationService.doNotDisturb ? "\uf1f6" : "\uf0f3"
                        active: NotificationService.doNotDisturb
                        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                    }

                    PanelIconButton {
                        icon: "\uf1f8"
                        enabled: NotificationService.history.count > 0
                        onClicked: NotificationService.clearHistory()
                    }

                    PanelIconButton {
                        icon: "\uf00d"
                        onClicked: NotificationService.closeCenter()
                    }
                }
            }

            // Пустой Центр.
            Item {
                width: parent.width
                height: NotificationService.history.count === 0 ? 130 : 0
                visible: height > 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\uf0f3"
                        color: Theme.quickTextDim
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 30
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Нет уведомлений"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }

            Flickable {
                id: flick

                width: parent.width
                visible: NotificationService.history.count > 0
                height: visible
                        ? Math.min(listColumn.implicitHeight,
                                   root.maxHeight - Theme.quickHeaderHeight
                                   - Theme.quickPadding * 2 - Theme.notificationSpacing)
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
    }

    // Кнопка шапки: тот же кружок, что у действий в шапках панелей.
    component PanelIconButton: Item {
        id: button

        property string icon: ""
        property bool active: false

        signal clicked()

        width: 30
        height: 30
        opacity: button.enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: button.active ? Theme.quickTileActive
                                 : (buttonHover.hovered ? Theme.quickTileHover : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.active ? Theme.accent : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 13
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
}
