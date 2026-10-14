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
    // Высота едет вместе с карточками: тот же тайминг, что у их съезда,
    // поэтому рамка не «раскрывается» отдельно от содержимого и нижнюю
    // карточку не обрезает при убирании.
    implicitHeight: column.implicitHeight

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.motionShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEmphasizedDecelerate
        }
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
                required property int index

                notification: entry
                context: "popup"
                staggerIndex: index
                width: column.width
            }
        }
    }
}
