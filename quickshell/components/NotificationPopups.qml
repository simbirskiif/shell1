import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../singletons"

// Всплывающие уведомления-тосты: правый верхний угол, под баром.
//
// Окно на каждый экран, но показывается только на экране с фокусом.
// Клавиатуру не забираем: тост не должен мешать печатать.
PanelWindow {
    id: root

    required property ShellScreen popupScreen

    readonly property string screenName: root.popupScreen ? root.popupScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: root.focusedScreenName === ""
                                             || root.focusedScreenName === root.screenName

    screen: popupScreen
    visible: NotificationService.popups.count > 0 && root.onFocusedScreen

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barHeight + Theme.notificationSpacing
        right: Theme.notificationSpacing
    }

    implicitWidth: Theme.notificationWidth
    // Окно не анимируем: «растущая рамка» выглядит как артефакт. Карточки
    // съезжают сами (Behavior on y), а высота растёт сразу и лишь сжимается
    // с задержкой — иначе нижнюю карточку обрежет во время съезда.
    readonly property real contentHeight: column.implicitHeight
    property real heldHeight: 0
    implicitHeight: Math.max(root.contentHeight, root.heldHeight)

    onContentHeightChanged: {
        if (root.contentHeight >= root.heldHeight)
            root.heldHeight = root.contentHeight;
        else
            holdTimer.restart();
    }

    Timer {
        id: holdTimer

        interval: Theme.motionShort4
        repeat: false
        onTriggered: root.heldHeight = root.contentHeight
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    Column {
        id: column

        anchors.fill: parent
        spacing: Theme.notificationSpacing

        Repeater {
            model: NotificationService.popups

            delegate: NotificationCard {
                required property var entry

                notification: entry
                context: "popup"
                width: column.width
            }
        }
    }
}
