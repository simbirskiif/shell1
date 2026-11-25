import QtQuick
import "../../singletons"

// Раздел «Бар»: живое превью правой части бара, добавление действий,
// перестановка мышью и настройка иконок.
SettingsPage {
    id: root

    property string selectedKey: MockState.firstBarItemKey()

    title: "Бар"
    description: "Клик выбирает элемент, перетаскивание меняет порядок."

    Component.onCompleted: {
        if (!MockState.barItemPresent(root.selectedKey))
            root.selectedKey = MockState.firstBarItemKey();
    }

    Connections {
        target: MockState

        // Элемент могли убрать снаружи (IPC, сброс): не оставляем настройки
        // иконки для несуществующего пункта.
        function onBarRevisionChanged() {
            if (!MockState.barItemPresent(root.selectedKey))
                root.selectedKey = MockState.firstBarItemKey();
        }
    }

    function titleFor(key) {
        return MockState.barItemTitles[key] || key;
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
        if (key === "wifi") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf1eb", label: "Wi-Fi" },
                { glyph: "\uf0ac", label: "Глобус" },
                { glyph: "\uf012", label: "Сигнал" }
            ];
        }
        if (key === "bluetooth") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf293", label: "Bluetooth" },
                { glyph: "\uf294", label: "Bluetooth B" },
                { glyph: "\uf10b", label: "Устройство" }
            ];
        }
        if (key === "brightness") {
            return [
                { glyph: "", label: "Авто" },
                { glyph: "\uf185", label: "Солнце" },
                { glyph: "\uf186", label: "Солнце 2" },
                { glyph: "\uf0eb", label: "Лампа" },
                { glyph: "\uf042", label: "Контраст" }
            ];
        }
        return [{ glyph: "", label: "Авто" }];
    }

    function statusOptions(slot) {
        if (slot === "wifi") {
            return [
                { value: "auto", glyph: "\uf021", label: "Авто" },
                { value: "", glyph: "\uf070", label: "Скрыть" },
                { value: "\uf1eb", glyph: "\uf1eb", label: "" },
                { value: "\uf0ac", glyph: "\uf0ac", label: "" },
                { value: "\uf012", glyph: "\uf012", label: "" }
            ];
        }
        if (slot === "bluetooth") {
            return [
                { value: "auto", glyph: "\uf021", label: "Авто" },
                { value: "", glyph: "\uf070", label: "Скрыть" },
                { value: "\uf293", glyph: "\uf293", label: "" },
                { value: "\uf294", glyph: "\uf294", label: "" }
            ];
        }
        return [
            { value: "auto", glyph: "\uf021", label: "Авто" },
            { value: "", glyph: "\uf070", label: "Скрыть" },
            { value: "\uf028", glyph: "\uf028", label: "" },
            { value: "\uf026", glyph: "\uf026", label: "" },
            { value: "\uf130", glyph: "\uf130", label: "" }
        ];
    }

    function addItem(key) {
        MockState.addBarItem(key);
        root.selectedKey = key;
    }

    function removeSelected() {
        MockState.removeBarItem(root.selectedKey);
        root.selectedKey = MockState.firstBarItemKey();
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

        Text {
            width: parent.width
            visible: MockState.barItems.count === 0
            text: "Бар пуст. Добавьте действие ниже."
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsCard {
        title: "Добавить действие"
        description: "Каждое действие открывает свою панель — Wi-Fi, Bluetooth или яркость."

        Repeater {
            model: MockState.availableBarItems()

            delegate: Item {
                required property string modelData

                width: parent.width
                height: Theme.touchTarget

                Text {
                    id: availableIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.space.xl
                    text: MockState.barItemIcon(modelData)
                    color: Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: availableIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: addButton.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.titleFor(modelData)
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                    elide: Text.ElideRight
                }

                SettingsButton {
                    id: addButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Добавить"
                    variant: "tonal"
                    onClicked: root.addItem(modelData)
                }
            }
        }

        Text {
            width: parent.width
            visible: MockState.availableBarItems().length === 0
            text: "Все доступные действия уже на барах."
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsCard {
        visible: root.selectedKey !== ""
        title: root.selectedKey === "status"
               ? "Пункт управления"
               : "Иконка: " + root.titleFor(root.selectedKey)
        description: root.selectedKey === "status"
                     ? "Каждый слот можно скрыть. Если скрыть все три, кнопка станет шестерёнкой."
                     : "«Авто» возвращает штатный вид элемента."

        Column {
            width: parent.width
            spacing: Theme.space.md
            visible: root.selectedKey === "status"

            BarSlotIconChoice {
                width: parent.width
                title: "Wi-Fi"
                options: root.statusOptions("wifi")
                value: MockState.statusIconFor("wifi")
                onPicked: value => MockState.setStatusIcon("wifi", value)
            }

            BarSlotIconChoice {
                width: parent.width
                title: "Bluetooth"
                options: root.statusOptions("bluetooth")
                value: MockState.statusIconFor("bluetooth")
                onPicked: value => MockState.setStatusIcon("bluetooth", value)
            }

            BarSlotIconChoice {
                width: parent.width
                title: "Звук"
                options: root.statusOptions("sound")
                value: MockState.statusIconFor("sound")
                onPicked: value => MockState.setStatusIcon("sound", value)
            }
        }

        BarIconPicker {
            visible: root.selectedKey !== "status"
            options: root.iconOptions(root.selectedKey)
            selectedGlyph: MockState.iconOverrideFor(root.selectedKey)
            onPicked: glyph => MockState.setBarIcon(root.selectedKey, glyph)
        }

        SettingsButton {
            text: "Убрать с бара"
            variant: "outlined"
            // Не оставляем бар без единого входа в настройки/панели.
            enabled: MockState.barItems.count > 1
            onClicked: root.removeSelected()
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
            onClicked: {
                MockState.resetBarSettings();
                root.selectedKey = MockState.firstBarItemKey();
            }
        }
    }
}
