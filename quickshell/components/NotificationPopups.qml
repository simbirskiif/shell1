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
    visible: NotificationService.popups.length > 0 && root.onFocusedScreen

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barHeight + Theme.notificationSpacing
        right: Theme.notificationSpacing
    }

    implicitWidth: Theme.notificationWidth
    implicitHeight: column.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    // Стопка растёт и сжимается мягко, а не рывком.
    Behavior on implicitHeight {
        MotionNumber {
            duration: Theme.motionMedium2
            curve: Theme.curveEmphasized
        }
    }

    Column {
        id: column

        anchors.fill: parent
        spacing: Theme.notificationSpacing

        Repeater {
            model: NotificationService.popups

            delegate: NotificationCard {
                required property var modelData

                notification: modelData
                context: "popup"
                width: column.width
            }
        }
    }
}
