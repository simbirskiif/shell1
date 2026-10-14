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
    visible: NotificationService.centerOpen && root.onFocusedScreen

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
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: NotificationService.closeCenter()
        }
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

        // Въезд панели справа.
        transform: Translate { id: panelShift; x: 0 }

        NumberAnimation {
            id: panelIn

            target: panelShift
            property: "x"
            from: panel.width
            to: 0
            duration: Theme.motionMedium1
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }

        onVisibleChanged: if (visible) panelIn.restart()

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

                    DialogButton {
                        text: "Очистить"
                        enabled: NotificationService.history.length > 0
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
                            required property var modelData

                            notification: modelData
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
                    visible: NotificationService.history.length === 0

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
        property bool primary: false

        signal triggered()

        width: (button.primary ? primaryLabel.implicitWidth : label.implicitWidth) + 24
        height: 28
        radius: height / 2
        color: button.primary ? Theme.accent : Theme.quickTile
        opacity: button.enabled ? 1 : 0.45

        Text {
            id: label

            anchors.centerIn: parent
            visible: !button.primary
            text: button.text
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            id: primaryLabel

            anchors.centerIn: parent
            visible: button.primary
            text: button.text
            color: Theme.quickIconOn
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
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
