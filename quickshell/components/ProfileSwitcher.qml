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

    BackgroundEffect.blurRegion: Region {
        item: card
        radius: Theme.shape.xl
    }
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

    // Меню M3: тональный контейнер surfaceContainer, радиус xl.
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 340
        height: column.implicitHeight + Theme.notificationPadding * 2
        radius: Theme.shape.xl
        color: Theme.sheetBlurSurface
        border.width: 1
        border.color: Theme.outlineVariant

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
                text: I18n.tr("switcher.profile.title")
                color: Theme.scheme.onSurface
                font: Theme.typeTitleMedium
            }

            Text {
                width: parent.width
                text: ProfileState.profiles.length === 0
                      ? I18n.tr("switcher.profile.empty", { path: ProfileState.profilesDir })
                      : I18n.tr("switcher.profile.description")
                color: Theme.scheme.onSurfaceVariant
                // Узкая карточка: вспомогательная подпись в одну строку,
                // поэтому bodySmall, а не bodyMedium.
                font: Theme.typeBodySmall
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

                    readonly property bool selected: row.index === root.cursor

                    width: list.width
                    // Пункт M3-меню: высота 48, радиус md.
                    height: Theme.touchTarget
                    radius: Theme.shape.md
                    color: row.selected ? Theme.secondaryContainer : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    HoverHandler {
                        id: hover
                    }

                    // Слой состояния M3 при наведении — под подписями.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(row.selected
                                                ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurface,
                                                Theme.stateHover)
                        opacity: hover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
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
                        anchors.leftMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData
                        color: row.selected ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface
                        font: Theme.typeBodyLarge
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.lg
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData === ProfileState.current
                        text: I18n.tr("common.current")
                        color: row.selected
                               ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.8)
                               : Theme.scheme.onSurfaceVariant
                        font: Theme.typeLabelMedium
                    }
                }
            }

            Text {
                width: parent.width
                visible: ProfileState.busy || ProfileState.lastError !== ""
                text: ProfileState.busy ? I18n.tr("switcher.profile.applying")
                                        : ProfileState.lastError
                color: ProfileState.busy ? Theme.scheme.onSurfaceVariant : Theme.error
                font: Theme.typeBodySmall
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: ProfileState.profiles.length > 0
                text: I18n.tr("switcher.profile.hint")
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
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
