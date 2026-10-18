pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"

// Обёртка одного экземпляра виджета (раздел 2 ТЗ).
//
// Shell рисует подложку и границы, виджет — только контент. В этапе 3 вместо
// простого Rectangle появится MaterialRegistry; здесь уже есть контракт:
// padding, radius и ctx передаются виджету.
//
// Ошибка загрузки локализуется в этой карточке и не затрагивает соседние
// экземпляры. Перезагрузка QML-файла виджета увеличивает reloadToken:
// Loader получает URL с новым query-параметром и заново читает файл с диска.
Item {
    id: root

    required property var instance
    required property var metrics
    required property var screen

    property bool editing: false
    property bool preview: false

    // Увеличивается при каждой перезагрузке QML — используется в URL.
    property int reloadToken: 0
    property bool _initialized: false

    readonly property var widget: root.instance
                                    ? WidgetRegistry.widgetById(root.instance.id)
                                    : null
    readonly property string widgetId: root.instance ? root.instance.id : ""
    readonly property string displayName: root.widget
                                           ? root.widget.name
                                           : (root.instance && root.instance.name
                                              ? root.instance.name : root.widgetId)

    // Геометрия в клетках с защитой от выхода за текущую сетку. Полноценная
    // миграция раскладки при смене сетки — этап 4.
    readonly property int gridCols: root.instance
                                      ? Math.max(1, Math.min(root.instance.cols, root.metrics.cols))
                                      : 1
    readonly property int gridRows: root.instance
                                      ? Math.max(1, Math.min(root.instance.rows, root.metrics.rows))
                                      : 1
    readonly property int safeCol: root.instance
                                     ? Math.max(0, Math.min(root.instance.col,
                                                            root.metrics.cols - root.gridCols))
                                     : 0
    readonly property int safeRow: root.instance
                                     ? Math.max(0, Math.min(root.instance.row,
                                                            root.metrics.rows - root.gridRows))
                                     : 0

    readonly property real padding: Math.round(root.metrics.cell * 0.12)
    readonly property string effectiveMaterial: root.instance && root.instance.material
                                                  ? root.instance.material
                                                  : Config.defaultMaterial
    readonly property string effectiveColorMode: root.instance && root.instance.colorMode
                                                   ? root.instance.colorMode
                                                   : Config.defaultColorMode

    property var currentSettings: ({})

    x: root.metrics.originX + root.safeCol * (root.metrics.cell + root.metrics.gap)
    y: root.metrics.originY + root.safeRow * (root.metrics.cell + root.metrics.gap)
    width: root.metrics.pixelWidth(root.gridCols)
    height: root.metrics.pixelHeight(root.gridRows)

    visible: root.instance !== null && root.instance !== undefined
    clip: true

    function refreshSettings(): void {
        if (!root.instance)
            return
        root.currentSettings = LayoutStore.settingsFor(root.instance.uid, root.widget)
    }

    function loadWidget(): void {
        if (!root.widget) {
            loader.active = false
            return
        }
        loader.active = true
        loader.setSource(root.widget.entryUrl + "?v=" + root.reloadToken,
                         { ctx: widgetContext })
        console.info("[widgets/host] загрузка " + root.widgetId
                     + " v" + root.reloadToken + " из " + root.widget.entryPath)
    }

    function reloadWidget(): void {
        if (!root._initialized)
            return
        // Манифест и файл могут прийти двумя сигналами подряд — склеиваем.
        reloadDebounce.restart()
    }

    function performReload(): void {
        root.reloadToken++
        root.refreshSettings()
        root.loadWidget()
    }

    Component.onCompleted: {
        root._initialized = true
        root.refreshSettings()
        root.loadWidget()
    }

    onWidgetChanged: {
        if (root._initialized)
            root.reloadWidget()
    }

    Timer {
        id: reloadDebounce
        interval: 40
        repeat: false
        onTriggered: root.performReload()
    }

    WidgetContext {
        id: widgetContext

        settingsData: root.currentSettings
        rows: root.gridRows
        cols: root.gridCols
        width: root.width
        height: root.height
        cell: root.metrics.cell
        dp: root.metrics.dp
        colorMode: root.effectiveColorMode
        material: root.effectiveMaterial
        editing: root.editing
        preview: root.preview
        screen: root.screen ? root.screen.name : ""

        onSettingRequested: (key, value) => {
            if (root.instance)
                LayoutStore.setSetting(root.instance.uid, key, value)
        }
    }

    Connections {
        target: LayoutStore

        function onInstanceChanged(uid) {
            if (root.instance && uid === root.instance.uid)
                root.refreshSettings()
        }
    }

    Connections {
        target: WidgetRegistry

        function onWidgetChanged(id) {
            if (id === root.widgetId)
                root.reloadWidget()
        }
    }

    // Подложка — зона ответственности shell. Материалы появятся на этапе 3.
    Rectangle {
        anchors.fill: parent
        radius: Math.round(root.metrics.cell * 0.28)
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.isDark ? "#22FFFFFF" : "#11000000"
    }

    Loader {
        id: loader

        anchors.fill: parent
        anchors.margins: root.padding
        asynchronous: true

        visible: status === Loader.Ready

        onStatusChanged: {
            if (status === Loader.Error)
                console.error("[widgets/host] " + root.widgetId + ": ошибка загрузки QML")
        }

        onLoaded: {
            const item = loader.item
            console.info("[widgets/host] загружен " + root.widgetId
                         + " item=" + (item ? item.width + "x" + item.height : "null")
                         + " host=" + root.width + "x" + root.height)
        }
    }

    // Карточка ошибки загрузки (раздел 9 ТЗ).
    WidgetStatusCard {
        anchors.fill: parent
        anchors.margins: root.padding
        visible: root.widget !== null && loader.status === Loader.Error
        icon: "⚠"
        title: root.displayName
        message: "Не удалось загрузить QML. Подробности в логе shell."
        showReload: true
        onReloadRequested: root.reloadWidget()
        onDeleteRequested: {
            if (root.instance)
                LayoutStore.removeInstance(root.instance.uid)
        }
    }

    // Плейсхолдер для виджета, папку которого удалили с диска (раздел 4 ТЗ).
    WidgetStatusCard {
        anchors.fill: parent
        anchors.margins: root.padding
        visible: root.widget === null
        icon: "◌"
        title: root.displayName
        message: "Виджет недоступен: " + root.widgetId
        showReload: false
        onDeleteRequested: {
            if (root.instance)
                LayoutStore.removeInstance(root.instance.uid)
        }
    }
}
