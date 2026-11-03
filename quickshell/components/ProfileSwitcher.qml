import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../singletons"

// Выбор профиля Hyprland: оверлей по центру экрана.
// Открывается биндом из профиля через IPC target "hyprProfile";
// сам ничего не пишет в конфиг — переключение делает hypr-profile.
PanelWindow {
    id: root

    required property ShellScreen pickerScreen

    readonly property string screenName: pickerScreen ? pickerScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: focusedScreenName === ""
                                             || focusedScreenName === root.screenName

    property int cursor: 0

    screen: pickerScreen
    visible: ProfileState.pickerOpen && root.onFocusedScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-hypr-profile"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function syncCursor() {
        const at = ProfileState.profiles.indexOf(ProfileState.current);
        root.cursor = at >= 0 ? at : 0;
    }

    function accept() {
        if (root.cursor >= 0 && root.cursor < ProfileState.profiles.length)
            ProfileState.switchTo(ProfileState.profiles[root.cursor]);
    }

    Component.onCompleted: root.syncCursor()

    Connections {
        target: ProfileState

        function onPickerOpenChanged() {
            if (!ProfileState.pickerOpen)
                return;
            root.syncCursor();
            keys.forceActiveFocus();
        }

        function onProfilesChanged() {
            root.syncCursor();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: ProfileState.close()
    }

    // Клик мимо карточки закрывает выбор.
    MouseArea {
        anchors.fill: parent
        onClicked: ProfileState.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 340
        height: column.implicitHeight + Theme.notificationPadding * 2
        radius: Theme.notificationRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        // Клики по карточке не должны закрывать её.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.notificationPadding
            spacing: Theme.notificationSpacing

            Text {
                text: "Профиль Hyprland"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: ProfileState.profiles.length === 0
                      ? "Нет профилей в " + ProfileState.profilesDir
                      : "Бинды, раскладка клавиатуры и правила окон"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            ListView {
                id: list

                width: parent.width
                height: Math.min(contentHeight, 320)
                model: ProfileState.profiles
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                delegate: Rectangle {
                    id: row

                    required property string modelData
                    required property int index

                    width: list.width
                    height: 42
                    radius: 8
                    color: row.index === root.cursor ? Theme.quickTileActive
                         : hover.hovered ? Theme.quickTileHover : "transparent"

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.cursor = row.index;
                            root.accept();
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData === ProfileState.current
                        text: "текущий"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                width: parent.width
                visible: ProfileState.busy || ProfileState.lastError !== ""
                text: ProfileState.busy ? "Применяю…" : ProfileState.lastError
                color: ProfileState.busy ? Theme.quickTextDim : Theme.lowColor
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: ProfileState.profiles.length > 0
                text: "↑/↓ — выбор, Enter — применить, Esc — закрыть"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    // Клавиатурный фокус: стрелки и Enter. Прозрачный Item не мешает мыши.
    Item {
        id: keys

        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
                root.cursor = Math.min(root.cursor + 1, ProfileState.profiles.length - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.cursor = Math.max(root.cursor - 1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.accept();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                ProfileState.close();
                event.accepted = true;
            }
        }
    }
}
