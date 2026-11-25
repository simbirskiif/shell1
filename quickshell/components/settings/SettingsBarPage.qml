import QtQuick
import "../../singletons"

// Раздел «Бар»: что показывать в правой части бара и в каком порядке.
SettingsPage {
    id: root

    title: "Бар"
    description: "Индикаторы справа от часов. Изменения применяются сразу."

    function titleFor(key, fallback) {
        if (key === "battery")
            return "Батарея";
        if (key === "notifications")
            return "Уведомления";
        if (key === "status")
            return "Быстрые настройки";
        return fallback;
    }

    SettingsCard {
        title: "Индикаторы"

        SettingsSwitchRow {
            title: "Процент батареи"
            description: "Показывать уровень заряда рядом с иконкой"
            checked: MockState.showBatteryPercent
            onToggled: MockState.showBatteryPercent = !MockState.showBatteryPercent
        }
    }

    SettingsCard {
        title: "Порядок элементов"
        description: "Слева направо — сверху вниз в этом списке."

        Repeater {
            model: MockState.barItems

            delegate: SettingsRow {
                title: root.titleFor(model.itemKey, model.title)
                description: model.itemKey

                Row {
                    spacing: Theme.space.xs

                    SettingsIconButton {
                        icon: "\uf077"
                        enabled: index > 0
                        onClicked: MockState.moveBarItem(index, -1)
                    }

                    SettingsIconButton {
                        icon: "\uf078"
                        enabled: index < MockState.barItems.count - 1
                        onClicked: MockState.moveBarItem(index, 1)
                    }
                }
            }
        }
    }

    SettingsButton {
        text: "Сбросить настройки бара"
        variant: "outlined"
        onClicked: MockState.resetBarSettings()
    }
}
