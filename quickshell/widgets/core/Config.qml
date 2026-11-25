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

    readonly property string home: Quickshell.env("HOME") || ""

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
    // Показывать сетку вне редактора. В редакторе она видна всегда.
    readonly property bool showGrid: adapter.grid.showGrid
    // Зарезервированные области (панели других клиентов), логические px.
    readonly property int reservedTop: adapter.grid.reserved.top
    readonly property int reservedRight: adapter.grid.reserved.right
    readonly property int reservedBottom: adapter.grid.reserved.bottom
    readonly property int reservedLeft: adapter.grid.reserved.left

    // --- Обнаружение виджетов (раздел 4 ТЗ) ---
    readonly property var extraPaths: adapter.widgets.extraPaths

    // Путь к файлу обоев для материала glass. Пусто — спросить hyprpaper.
    readonly property string wallpaper: adapter.wallpaper

    // Добавить путь поиска виджетов и сохранить конфиг.
    function addExtraPath(path: string): bool {
        let value = String(path).trim()
        if (value.length === 0)
            return false
        if (value === "~")
            value = root.home + ""
        else if (value.startsWith("~/"))
            value = root.home + value.slice(1)
        if (!value.startsWith("/"))
            return false
        if (value.length > 1 && value.endsWith("/"))
            value = value.slice(0, -1)

        const paths = []
        for (const existing of adapter.widgets.extraPaths)
            paths.push(existing)
        if (paths.indexOf(value) >= 0)
            return false
        paths.push(value)
        adapter.widgets.extraPaths = paths
        configFile.writeAdapter()
        console.info("[widgets/config] добавлен путь: " + value)
        return true
    }

    // --- Значения по умолчанию для экземпляров (раздел 6 ТЗ) ---
    readonly property string defaultMaterial: adapter.defaults.material
    readonly property string defaultColorMode:
        adapter.defaults.colorMode === "neutral" ? "neutral" : "accent"
    readonly property real defaultMaterialDim: {
        const value = Number(adapter.defaults.dim)
        return Number.isFinite(value)
             ? Math.max(0.10, Math.min(0.95, value)) : 0.60
    }

    // Глобальные параметры виджетов. Экземпляр может переопределить любой
    // из них, выбрав «По умолчанию» в своих настройках.
    function setDefaultMaterial(materialId: string): bool {
        const value = String(materialId || "")
        if (value.length === 0)
            return false
        adapter.defaults.material = value
        configFile.writeAdapter()
        console.info("[widgets/config] материал по умолчанию: " + value)
        return true
    }

    function setDefaultColorMode(mode: string): bool {
        if (mode === "widget")
            mode = "neutral"
        if (mode !== "accent" && mode !== "neutral")
            return false
        adapter.defaults.colorMode = mode
        configFile.writeAdapter()
        console.info("[widgets/config] режим цвета по умолчанию: " + mode)
        return true
    }

    function setDefaultMaterialDim(value: real): bool {
        const normalized = Math.max(0.10, Math.min(0.95, Number(value)))
        if (!Number.isFinite(normalized))
            return false
        adapter.defaults.dim = normalized
        configFile.writeAdapter()
        return true
    }

    // Отладочная сетка: раньше ключ правился только руками в config.json,
    // теперь у него есть переключатель в окне настроек.
    function setShowGrid(value: bool): bool {
        adapter.grid.showGrid = value === true
        configFile.writeAdapter()
        return true
    }

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

        onSaveFailed: (error) => console.warn("[widgets/config] не сохранён: " + error)

        JsonAdapter {
            id: adapter

            property JsonObject grid: JsonObject {
                property real cellTargetMm: 16
                property real outerMarginMm: 6
                property real gapRatio: 0.12
                property int minCols: 4
                property int maxCols: 24
                property real dpiOverride: 0
                property bool showGrid: false
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

            property string wallpaper: ""

            property JsonObject defaults: JsonObject {
                property string material: "glass"
                property string colorMode: "accent"
                property real dim: 0.60
            }
        }
    }
}
