import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "expressive"
import "../singletons"

// Выбор профиля Hyprland: оверлей по центру экрана в духе M3 Expressive
// menu. Крупные пункты 56: активный — форма cookie на tertiaryContainer,
// остальные — спокойная пилюля; наведение даёт слой состояния той же формы.
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

    // Меню Expressive: тональная поверхность, крупное скругление 32, без
    // обводки — контейнер отделяется тоном и воздухом.
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 372
        height: column.implicitHeight + Theme.notificationPadding * 2
        radius: Theme.shape.xlIncreased
        color: Theme.sheetSurface

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
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedTitleMedium
            }

            Text {
                width: parent.width
                text: ProfileState.profiles.length === 0
                      ? "Нет профилей в " + ProfileState.profilesDir
                      : "Бинды, раскладка клавиатуры и правила окон"
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
                spacing: Theme.space.xs
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                delegate: Item {
                    id: row

                    required property string modelData
                    required property int index

                    readonly property bool selected: row.index === root.cursor

                    width: list.width
                    // Крупный пункт меню: 56 вместо прежних 48.
                    height: Theme.listItemHeight
                    // Нажатие сжимает пункт пружиной; выбор читается формой.
                    scale: rowMouse.pressed ? 0.97 : 1
                    Behavior on scale { SpringSpatialFast {} }

                    // Активный пункт — «печенье» на tertiaryContainer,
                    // неактивные — спокойная пилюля без контейнера.
                    MorphShape {
                        anchors.fill: parent
                        shape: row.selected ? "pill" : "squircle"
                        color: row.selected ? Theme.tertiaryContainer : "transparent"
                        modulation: row.selected ? 0.5 : 0.25
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                    }

                    // Слой состояния при наведении — той же морфящейся
                    // формой, чтобы не выходить за волнистый контур.
                    MorphShape {
                        anchors.fill: parent
                        shape: row.selected ? "pill" : "squircle"
                        modulation: row.selected ? 0.5 : 0.25
                        color: row.selected
                               ? Theme.withAlpha(Theme.scheme.onTertiaryContainer, Theme.stateHover)
                               : Theme.withAlpha(Theme.scheme.onSurface, Theme.stateHover)
                        opacity: rowMouse.containsMouse ? 1 : 0
                        Behavior on opacity { SpringEffects {} }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.xl
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData
                        color: row.selected ? Theme.scheme.onTertiaryContainer
                                            : Theme.scheme.onSurface
                        font: row.selected ? Theme.typeEmphasizedTitleMedium
                                           : Theme.typeBodyLarge
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.xl
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData === ProfileState.current
                        text: "текущий"
                        color: row.selected
                               ? Theme.withAlpha(Theme.scheme.onTertiaryContainer, 0.8)
                               : Theme.scheme.onSurfaceVariant
                        font: Theme.typeLabelMedium
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cursor = row.index;
                            root.accept();
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: ProfileState.busy || ProfileState.lastError !== ""
                text: ProfileState.busy ? "Применяю…" : ProfileState.lastError
                color: ProfileState.busy ? Theme.scheme.onSurfaceVariant : Theme.error
                font: Theme.typeBodySmall
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: ProfileState.profiles.length > 0
                text: "↑/↓ — выбор, Enter — применить, Esc — закрыть"
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
