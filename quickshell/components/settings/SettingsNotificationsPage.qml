import QtQuick
import "../../singletons"

// Раздел «Уведомления»: режим «не беспокоить» и чувствительность жеста.
SettingsPage {
    id: root

    title: I18n.tr("settings.notifications.title")
    description: I18n.tr("settings.notifications.description")

    SettingsCard {
        title: I18n.tr("settings.notifications.mode.title")

        SettingsSwitchRow {
            title: I18n.tr("quick.tile.dnd")
            description: I18n.tr("settings.notifications.dnd.description")
            checked: NotificationService.doNotDisturb
            onToggled: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
        }
    }

    SettingsCard {
        title: I18n.tr("settings.notifications.gesture.title")

        SettingsSliderRow {
            title: I18n.tr("settings.notifications.swipe.title")
            description: I18n.tr("settings.notifications.swipe.description")
            value: (NotificationService.swipeSensitivity - 0.5) / 2.5
            valueText: NotificationService.swipeSensitivity.toFixed(2) + "×"
            onMoved: v => NotificationService.swipeSensitivity =
                          Math.round((0.5 + v * 2.5) * 20) / 20
        }
    }

    SettingsButton {
        text: I18n.tr("common.reset")
        variant: "outlined"
        onClicked: {
            NotificationService.doNotDisturb = false;
            NotificationService.swipeSensitivity = 1.0;
        }
    }
}
