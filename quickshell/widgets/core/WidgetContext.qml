import QtQuick
import "../../singletons"
import Quickshell

// Контекст, который shell инъектирует в корень виджета (раздел 3.5 ТЗ).
//
// Создаётся WidgetHost'ом на каждый экземпляр. Виджет получает объект через
// `required property var ctx` и читает его; менять раскладку он не может.
// Настройки экземпляра меняются только через ctx.setSetting().
QtObject {
    id: root

    // --- Данные, которые заполняет host ---
    // Текущие значения настроек; host заменяет объект целиком, чтобы
    // биндинги вида ctx.settings.foo пересчитались.
    property var settingsData: ({})
    property int rows: 0
    property int cols: 0
    property int width: 0
    property int height: 0
    property int cell: 0
    property real dp: 1
    property string colorMode: "accent"
    property string material: "solid"
    property bool editing: false
    property bool preview: false
    property string screen: ""

    // Палитра, уже разрешённая по режиму accent/widget и схеме shell.
    property var colorsData: Theme.colors

    // --- Публичный контракт (только чтение для виджета) ---
    readonly property var colors: colorsData
    readonly property bool isDark: Theme.isDark
    readonly property var settings: settingsData

    // Компактный/средний/крупный по меньшей стороне (раздел 3.5).
    readonly property string sizeClass: {
        const side = Math.min(rows, cols)
        if (side <= 1) return "compact"
        if (side >= 3) return "large"
        return "medium"
    }

    // Запись настройки экземпляра. Host сохраняет её в раскладке и обновляет
    // settingsData; виджет не знает, куда именно она пишется.
    signal settingRequested(string key, var value)

    function setSetting(key: string, value: var): void {
        root.settingRequested(key, value)
    }
}
