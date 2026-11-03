import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../singletons"

// Просмотр окон (SUPER+TAB): оверлей по центру экрана.
// Список — WindowState, активация — hyprctl-диспетчер focus по адресу.
PanelWindow {
    id: root

    required property ShellScreen pickerScreen

    readonly property string screenName: pickerScreen ? pickerScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: focusedScreenName === ""
                                             || focusedScreenName === root.screenName

    screen: pickerScreen
    visible: WindowState.open && root.onFocusedScreen
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Клик мимо или потеря фокуса закрывают список, чтобы он не залипал.
    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: WindowState.cancel()
    }

    function accept() {
        WindowState.activate();
    }

    Connections {
        target: WindowState

        function onOpenChanged() {
            if (WindowState.open)
                keys.forceActiveFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: WindowState.close()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WindowState.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 460
        height: column.implicitHeight + Theme.notificationPadding * 2
        radius: Theme.notificationRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.notificationPadding
            spacing: Theme.notificationSpacing

            Text {
                text: "Окна"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                visible: WindowState.windows.length === 0 && WindowState.lastError === ""
                text: "Нет открытых окон"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            ListView {
                id: list

                width: parent.width
                height: Math.min(contentHeight, 360)
                model: WindowState.windows
                currentIndex: WindowState.cursor
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: list.width
                    height: 46
                    radius: 8
                    color: row.index === WindowState.cursor ? Theme.quickTileActive
                         : hover.hovered ? Theme.quickTileHover : "transparent"

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            WindowState.cursor = row.index;
                            WindowState.activate();
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.topMargin: 5
                        text: row.modelData.appClass + "  ·  " + row.modelData.workspace
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        text: row.modelData.title
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                width: parent.width
                visible: WindowState.lastError !== ""
                text: WindowState.lastError
                color: Theme.lowColor
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: WindowState.windows.length > 0
                text: "↑/↓ — выбор, Enter — перейти, Esc — закрыть"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
                WindowState.move(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                WindowState.move(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.accept();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                WindowState.cancel();
                event.accepted = true;
            }
        }

        // Отпускание Alt подтверждает выбор, как в Windows Alt+Tab.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
                WindowState.commit();
                event.accepted = true;
            }
        }
    }
}
