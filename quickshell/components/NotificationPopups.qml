import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../singletons"

// Всплывающие уведомления-тосты: правый верхний угол, под баром.
//
// Поверхность держим постоянного размера и НЕ анимируем её высоту: на
// layer-shell анимация размера заставляет композитор тянуть старый буфер —
// это и есть «уменьшающийся прямоугольник», который дёргается при убирании
// тоста. Карточки прекрасно едут внутри поверхности сами, а клики мимо
// стопки пропускает маска (она режет только ввод, не отрисовку).
PanelWindow {
    id: root

    required property ShellScreen popupScreen

    readonly property string screenName: root.popupScreen ? root.popupScreen.name : ""
    readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property bool onFocusedScreen: root.focusedScreenName === ""
                                             || root.focusedScreenName === root.screenName
    // Запас на всю высоту экрана: стопка может быть любой, а поверхность
    // от этого не меняется.
    readonly property real stackLimit: root.popupScreen
                                       ? root.popupScreen.height - Theme.barHeight - 16 : 600

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
    implicitHeight: root.stackLimit
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    // Ввод ловим ровно в области стопки, остальное пропускаем вниз.
    mask: Region {
        item: column
    }

    Column {
        id: column

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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
