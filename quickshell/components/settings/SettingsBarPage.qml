import QtQuick
import "../../singletons"

// Раздел «Бар»: живое превью правой части бара, перестановка мышью и
// персональная иконка для каждого элемента.
SettingsPage {
    id: root

    property string selectedKey: "battery"

    title: "Бар"
    description: "Клик по элементу выбирает его, перетаскивание меняет порядок."

    function titleFor(key) {
        if (key === "battery")
            return "Батарея";
        if (key === "notifications")
            return "Уведомления";
        if (key === "status")
            return "Пункт управления";
        return key;
    }

    function iconOptions(key) {
        if (key === "battery") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf240", label: "Полная" },
                { glyph: "\uf241", label: "3/4" },
                { glyph: "\uf242", label: "1/2" },
                { glyph: "\uf243", label: "1/4" },
                { glyph: "\uf244", label: "Пустая" },
                { glyph: "\uf0e7", label: "Молния" },
                { glyph: "\uf1e6", label: "Вилка" }
            ];
        }
        if (key === "notifications") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf0f3", label: "Колокол" },
                { glyph: "\uf1f6", label: "Без звука" },
                { glyph: "\uf0e0", label: "Конверт" },
                { glyph: "\uf27a", label: "Сообщение" },
                { glyph: "\uf12a", label: "Важно" },
                { glyph: "\uf024", label: "Флаг" },
                { glyph: "\uf111", label: "Точка" }
            ];
        }
        return [
            { glyph: "", label: "Авто" },
            { glyph: "\uf1de", label: "Ползунки" },
            { glyph: "\uf009", label: "Сетка" },
            { glyph: "\uf013", label: "Настройки" },
            { glyph: "\uf1eb", label: "Wi-Fi" },
            { glyph: "\uf293", label: "Bluetooth" },
            { glyph: "\uf028", label: "Звук" },
            { glyph: "\uf0e7", label: "Питание" }
        ];
    }

    SettingsCard {
        title: "Правая часть бара"
        description: "Порядок и вид элементов — как в настоящем баре."

        BarPreview {
            width: parent.width
            selectedKey: root.selectedKey
            onSelected: key => root.selectedKey = key
        }

        SettingsSwitchRow {
            title: "Процент батареи"
            description: "Показывать уровень заряда рядом с иконкой"
            checked: MockState.showBatteryPercent
            onToggled: MockState.showBatteryPercent = !MockState.showBatteryPercent
        }
    }

    SettingsCard {
        title: "Иконка: " + root.titleFor(root.selectedKey)
        description: root.selectedKey === "status"
                     ? "«Авто» — составной индикатор Bluetooth/Wi-Fi/звука; иконка заменяет его."
                     : "«Авто» возвращает штатный вид элемента."

        BarIconPicker {
            options: root.iconOptions(root.selectedKey)
            selectedGlyph: MockState.iconOverrideFor(root.selectedKey)
            onPicked: glyph => MockState.setBarIcon(root.selectedKey, glyph)
        }
    }

    Row {
        spacing: Theme.space.sm

        SettingsButton {
            text: "Сбросить иконки"
            variant: "outlined"
            onClicked: MockState.resetBarIcons()
        }

        SettingsButton {
            text: "Сбросить бар"
            variant: "outlined"
            onClicked: MockState.resetBarSettings()
        }
    }
}
