import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "quick"
import "../singletons"

// Центр уведомлений: панель справа со всей историей.
//
// Список листается вертикально двумя пальцами (Flickable), а карточки
// смахиваются горизонтально: WheelHandler на карточке берёт только
// горизонтальную ось и не мешает вертикальному скроллу.
PanelWindow {
    id: root

    required property ShellScreen centerScreen

    readonly property string screenName: root.centerScreen ? root.centerScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: root.focusedScreenName === ""
                                             || root.focusedScreenName === root.screenName

    screen: centerScreen
    // Видимость ведём сами: окно должно успеть выехать, прежде чем исчезнуть.
    property bool shown: false
    visible: root.shown && root.onFocusedScreen

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
        root.shown = true;
        panelShift.x = panel.width;
        panelIn.restart();
        backdropIn.restart();
    }

    function disappear() {
        if (!root.shown)
            return;
        panelOut.restart();
        backdropOut.restart();
    }

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

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: NotificationService.closeCenter()
    }

    // Клик мимо панели закрывает Центр.
    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: NotificationService.closeCenter()
        }
    }

    NumberAnimation {
        id: backdropIn

        target: backdrop
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.motionShort4
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveStandardDecelerate
    }

    NumberAnimation {
        id: backdropOut

        target: backdrop
        property: "opacity"
        from: 1
        to: 0
        duration: Theme.motionShort3
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveStandardAccelerate
    }

    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Math.min(Theme.notificationCenterWidth, parent.width - 32)
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        // Въезд и выезд панели справа.
        transform: Translate { id: panelShift; x: 0 }

        NumberAnimation {
            id: panelIn

            target: panelShift
            property: "x"
            from: panel.width
            to: 0
            duration: Theme.motionShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }

        NumberAnimation {
            id: panelOut

            target: panelShift
            property: "x"
            from: 0
            to: panel.width
            duration: Theme.motionShort3
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEmphasizedAccelerate
            // Прячем окно только после того, как панель уехала.
            onStopped: {
                if (!NotificationService.centerOpen)
                    root.shown = false;
            }
        }

        // Клики по панели не должны закрывать её через подложку.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: layout

            anchors.fill: parent
            anchors.margins: Theme.quickPadding
            spacing: Theme.notificationSpacing

            Item {
                id: header

                width: parent.width
                height: 32

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Уведомления"
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Режим «не беспокоить» прямо в окне: та же плитка, что и
                    // в быстрых настройках, только компактно.
                    DialogButton {
                        icon: NotificationService.doNotDisturb ? "\uf1f6" : "\uf0f3"
                        active: NotificationService.doNotDisturb
                        onTriggered: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                    }

                    DialogButton {
                        text: "Очистить"
                        enabled: NotificationService.history.count > 0
                        onTriggered: NotificationService.clearHistory()
                    }

                    DialogButton {
                        text: "Закрыть"
                        primary: true
                        onTriggered: NotificationService.closeCenter()
                    }
                }
            }

            Flickable {
                id: flick

                width: parent.width
                // Высота — всё, что осталось под шапкой.
                height: layout.height - header.height - layout.spacing
                contentHeight: listColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listColumn

                    width: flick.width
                    spacing: Theme.notificationSpacing

                    Repeater {
                        model: NotificationService.history

                        delegate: NotificationCard {
                            required property var entry

                            notification: entry
                            context: "center"
                            width: listColumn.width
                        }
                    }
                }

                // Пустой Центр.
                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 8
                    visible: NotificationService.history.count === 0

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
        }
    }

    // Кнопка панели: та же форма, что у прочих кнопок оболочки.
    component DialogButton: Rectangle {
        id: button

        property string text: ""
        property string icon: ""
        property bool primary: false
        // Включённое состояние (например, «не беспокоить»).
        property bool active: false

        signal triggered()

        width: content.implicitWidth + 24
        height: 28
        radius: height / 2
        color: button.primary ? Theme.accent
                              : (button.active ? Theme.quickTileActive : Theme.quickTile)
        border.width: button.active && !button.primary ? 1 : 0
        border.color: Theme.accent
        opacity: button.enabled ? 1 : 0.45

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.icon !== ""
                text: button.icon
                color: button.primary ? Theme.quickIconOn
                                      : (button.active ? Theme.accent : Theme.quickText)
                font.family: Theme.iconFontFamily
                font.pixelSize: 12
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.text !== ""
                text: button.text
                color: button.primary ? Theme.quickIconOn
                                      : (button.active ? Theme.accent : Theme.quickText)
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: button.primary ? Font.Medium : Font.Normal
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
