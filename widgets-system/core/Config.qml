pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Пользовательский конфиг системы виджетов.
//
// Файл: $XDG_CONFIG_HOME/quickshell/widgets/config.json
// Если файла нет, работают значения по умолчанию, объявленные ниже.
// Неизвестные ключи в файле игнорируются.
//
// Свойства сгруппированы по смыслу и намеренно отдаются наружу «плоско»
// (Config.cellTargetMm, а не Config.grid.cellTargetMm), чтобы вызывающий код
// не зависел от формы JSON.
Singleton {
    id: root

    // Путь к файлу конфига (XDG-каталог Quickshell).
    // configDir/shellDir помечены в 0.3.2 как deprecated, поэтому собираем
    // путь из XDG-переменных.
    readonly property string configBase: {
        const explicit = Quickshell.env("XDG_CONFIG_HOME")
        const home = Quickshell.env("HOME") || ""
        return (explicit && explicit.length > 0 ? explicit : home + "/.config")
               + "/quickshell"
    }
    readonly property string filePath: root.configBase + "/widgets/config.json"

    // Загружен ли файл. false — файла нет или он ещё не прочитан;
    // в этом случае действуют значения по умолчанию из JsonAdapter.
    readonly property bool loaded: configFile.loaded

    // --- Сетка (раздел 5 ТЗ) ---
    // Целевой физический размер клетки, мм.
    readonly property real cellTargetMm: adapter.grid.cellTargetMm
    // Внешний отступ сетки от края экрана, мм.
    readonly property real outerMarginMm: adapter.grid.outerMarginMm
    // Доля целевой клетки, уходящая в промежуток между клетками.
    readonly property real gapRatio: adapter.grid.gapRatio
    // Ограничения числа столбцов.
    readonly property int minCols: adapter.grid.minCols
    readonly property int maxCols: adapter.grid.maxCols
    // Переопределение плотности (px/мм). 0 — определять по экрану.
    readonly property real dpiOverride: adapter.grid.dpiOverride
    // Показывать отладочную сетку (этап 1; позже — только в редакторе).
    readonly property bool showGrid: adapter.grid.showGrid
    // Зарезервированные области (панели других клиентов), логические px.
    readonly property int reservedTop: adapter.grid.reserved.top
    readonly property int reservedRight: adapter.grid.reserved.right
    readonly property int reservedBottom: adapter.grid.reserved.bottom
    readonly property int reservedLeft: adapter.grid.reserved.left

    // --- Обнаружение виджетов (раздел 4 ТЗ) ---
    readonly property var extraPaths: adapter.widgets.extraPaths

    // --- Оформление ---
    // "dark" | "light"; этап 3 расширит до выбора палитры/акцента.
    readonly property string theme: adapter.theme
    // Путь к файлу обоев для материала glass. Пусто — спросить hyprpaper.
    readonly property string wallpaper: adapter.wallpaper

    // --- Значения по умолчанию для экземпляров (раздел 6 ТЗ) ---
    readonly property string defaultMaterial: adapter.defaults.material
    readonly property string defaultColorMode: adapter.defaults.colorMode

    // Каталоги для пользовательских настроек/материалов. Создаём заранее,
    // чтобы наблюдатели за папками не пропускали вложенное создание.
    Process {
        command: ["mkdir", "-p",
                  root.configBase + "/widgets",
                  root.configBase + "/widgets/materials"]
        running: true
    }

    FileView {
        id: configFile

        path: root.filePath
        watchChanges: true
        preload: true
        // Отсутствие конфига — нормальное состояние, не засоряем лог.
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter

            property JsonObject grid: JsonObject {
                property real cellTargetMm: 16
                property real outerMarginMm: 6
                property real gapRatio: 0.12
                property int minCols: 4
                property int maxCols: 24
                property real dpiOverride: 0
                property bool showGrid: true
                property JsonObject reserved: JsonObject {
                    property int top: 0
                    property int right: 0
                    property int bottom: 0
                    property int left: 0
                }
            }

            property JsonObject widgets: JsonObject {
                property list<string> extraPaths: []
            }

            property string theme: "dark"
            property string wallpaper: ""

            property JsonObject defaults: JsonObject {
                property string material: "glass"
                property string colorMode: "accent"
            }
        }
    }
}
