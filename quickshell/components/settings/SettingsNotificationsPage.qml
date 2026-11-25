import QtQuick
import "../../singletons"

// Раздел «Уведомления»: режим «не беспокоить» и чувствительность жеста.
SettingsPage {
    id: root

    title: "Уведомления"
    description: "Поведение тостов и истории уведомлений."

    SettingsCard {
        title: "Режим"

        SettingsSwitchRow {
            title: "Не беспокоить"
            description: "История пополняется, тосты не показываются. Критичные уведомления приходят."
            checked: NotificationService.doNotDisturb
            onToggled: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
        }
    }

    SettingsCard {
        title: "Жест"

        SettingsSliderRow {
            title: "Чувствительность свайпа"
            description: "1.00× — карточка идёт ровно за пальцами"
            value: (NotificationService.swipeSensitivity - 0.5) / 2.5
            valueText: NotificationService.swipeSensitivity.toFixed(2) + "×"
            onMoved: v => NotificationService.swipeSensitivity =
                          Math.round((0.5 + v * 2.5) * 20) / 20
        }
    }

    SettingsButton {
        text: "Сбросить"
        variant: "outlined"
        onClicked: {
            NotificationService.doNotDisturb = false;
            NotificationService.swipeSensitivity = 1.0;
        }
    }
}
