pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../editor"

// Обёртка одного экземпляра виджета (раздел 2 ТЗ).
//
// Shell рисует подложку (материал) и передаёт палитру, виджет — только
// контент. Изменение материала или режима цвета не перезагружает контент:
// материал живёт в отдельном Loader, а ctx.colors обновляется на месте.
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

    // Локальные копии переопределений экземпляра: LayoutStore меняет поля
    // объекта, а не сам объект, поэтому нужен явный refresh при
    // instanceChanged.
    property string instanceMaterial: ""
    property string instanceColorMode: ""
    property int materialToken: 0
    property string loadedMaterialUrl: ""

    readonly property var widget: root.instance
                                    ? WidgetRegistry.widgetById(root.instance.id)
                                    : null
    readonly property string widgetId: root.instance ? root.instance.id : ""
    readonly property string displayName: root.widget
                                           ? root.widget.name
                                           : (root.instance && root.instance.name
                                              ? root.instance.name : root.widgetId)

    // Локальная геометрия карточки. Обновляется из LayoutStore без пересборки
    // Repeater, чтобы отпускание после drag/resize анимировалось в цель.
    property int displayCol: 0
    property int displayRow: 0
    property int displayCols: 1
    property int displayRows: 1

    readonly property int gridCols:
        Math.max(1, Math.min(root.displayCols, root.metrics.cols))
    readonly property int gridRows:
        Math.max(1, Math.min(root.displayRows, root.metrics.rows))
    readonly property int safeCol:
        Math.max(0, Math.min(root.displayCol, root.metrics.cols - root.gridCols))
    readonly property int safeRow:
        Math.max(0, Math.min(root.displayRow, root.metrics.rows - root.gridRows))

    readonly property bool dragActive: DragController.active && root.instance
                                       && DragController.uid === root.instance.uid
    readonly property real baseX:
        root.metrics.originX + root.safeCol * (root.metrics.cell + root.metrics.gap)
    readonly property real baseY:
        root.metrics.originY + root.safeRow * (root.metrics.cell + root.metrics.gap)

    readonly property bool previewing: DragController.active && root.instance
                                       && DragController.uid === root.instance.uid
    readonly property int liveCols: root.previewing ? DragController.cols : root.gridCols
    readonly property int liveRows: root.previewing ? DragController.rows : root.gridRows
    readonly property real liveWidth: root.previewing
                                       ? root.metrics.pixelWidth(DragController.cols)
                                       : root.width
    readonly property real liveHeight: root.previewing
                                       ? root.metrics.pixelHeight(DragController.rows)
                                       : root.height

    readonly property real padding: Math.round(root.metrics.cell * 0.12)
    readonly property real materialRadius: Math.round(root.metrics.cell * 0.28)
    // Смещение окна слоя внутри экрана: верхняя/боковая панель композитора.
    readonly property real screenOffsetX:
        root.screen ? Math.max(0, root.screen.width - root.metrics.areaWidth) : 0
    readonly property real screenOffsetY:
        root.screen ? Math.max(0, root.screen.height - root.metrics.areaHeight) : 0

    readonly property string effectiveColorMode: {
        const requested = root.instanceColorMode.length > 0
                        ? root.instanceColorMode : Config.defaultColorMode
        const modes = root.widget ? root.widget.colorModes : ["accent", "widget"]
        if (modes.length === 0)
            return "accent"
        return modes.indexOf(requested) >= 0 ? requested : modes[0]
    }

    readonly property var effectiveColors:
        Theme.colorsFor(root.effectiveColorMode, root.widget)

    readonly property string effectiveMaterial: {
        const requested = root.instanceMaterial.length > 0
                        ? root.instanceMaterial : Config.defaultMaterial
        const allowed = root.widget && root.widget.materials
                      ? root.widget.materials : ["any"]
        const permits = function(id) {
            return allowed.indexOf("any") >= 0 || allowed.indexOf(id) >= 0
        }

        if (permits(requested) && MaterialRegistry.materialById(requested))
            return requested
        for (const id of allowed) {
            if (id !== "any" && MaterialRegistry.materialById(id))
                return id
        }
        if (MaterialRegistry.materialById("solid"))
            return "solid"
        return MaterialRegistry.materials.length > 0
             ? MaterialRegistry.materials[0].id : requested
    }

    property var currentSettings: ({})

    x: root.baseX + (root.dragActive && DragController.mode === "drag"
                     ? DragController.dx : 0)
    y: root.baseY + (root.dragActive && DragController.mode === "drag"
                     ? DragController.dy : 0)
    width: root.metrics.pixelWidth(root.gridCols)
    height: root.metrics.pixelHeight(root.gridRows)

    visible: root.instance !== null && root.instance !== undefined
    clip: true

    Behavior on x {
        enabled: !root.dragActive
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !root.dragActive
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        enabled: !root.dragActive
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: !root.dragActive
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function refreshSettings(): void {
        if (!root.instance)
            return
        root.currentSettings = LayoutStore.settingsFor(root.instance.uid, root.widget)
    }

    function refreshGeometry(): void {
        if (!root.instance)
            return
        const current = LayoutStore.findInstance(root.instance.uid)
        if (!current)
            return
        root.displayCol = current.col
        root.displayRow = current.row
        root.displayCols = current.cols
        root.displayRows = current.rows
    }

    function refreshInstance(): void {
        if (!root.instance)
            return
        // Repeater передаёт modelData как копию объекта, поэтому актуальные
        // переопределения читаем из LayoutStore по uid.
        const current = LayoutStore.findInstance(root.instance.uid)
        root.instanceMaterial = current ? (current.material || "") : ""
        root.instanceColorMode = current ? (current.colorMode || "") : ""
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

    function loadMaterial(force: bool): void {
        const material = MaterialRegistry.materialById(root.effectiveMaterial)
        if (!material) {
            materialLoader.active = false
            root.loadedMaterialUrl = ""
            return
        }
        if (!force && material.url === root.loadedMaterialUrl
            && materialLoader.status === Loader.Ready)
            return
        root.loadedMaterialUrl = material.url
        root.materialToken++
        materialLoader.active = true
        materialLoader.setSource(material.url + "?v=" + root.materialToken, {
            colors: root.effectiveColors,
            radius: root.materialRadius,
            size: Qt.size(root.width, root.height),
            wallpaperSource: Wallpaper.sourceUrl,
            offsetX: root.x + root.screenOffsetX,
            offsetY: root.y + root.screenOffsetY,
            screenWidth: root.screen ? root.screen.width : 0,
            screenHeight: root.screen ? root.screen.height : 0,
            editing: root.editing
        })
        console.info("[widgets/material] " + root.widgetId + " <- " + material.id
                     + " v" + root.materialToken)
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
        root.refreshInstance()
        root.refreshGeometry()
        root.loadWidget()
        root.loadMaterial(true)
    }

    onWidgetChanged: {
        if (root._initialized)
            root.reloadWidget()
    }

    onEffectiveMaterialChanged: {
        if (root._initialized)
            root.loadMaterial(false)
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
        colorsData: root.effectiveColors
        rows: root.liveRows
        cols: root.liveCols
        width: root.liveWidth
        height: root.liveHeight
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
            if (root.instance && uid === root.instance.uid) {
                root.refreshSettings()
                root.refreshInstance()
                root.refreshGeometry()
            }
        }
    }

    Connections {
        target: WidgetRegistry

        function onWidgetChanged(id) {
            if (id === root.widgetId)
                root.reloadWidget()
        }
    }

    Connections {
        target: MaterialRegistry

        function onMaterialsChanged() {
            if (root._initialized)
                root.loadMaterial(false)
        }

        function onMaterialChanged(id) {
            if (id === root.effectiveMaterial)
                root.loadMaterial(true)
        }
    }

    // --- Материал подложки (раздел 6.1 ТЗ) ---
    Rectangle {
        id: materialFallback

        anchors.fill: parent
        visible: materialLoader.status !== Loader.Ready
        radius: root.materialRadius
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.isDark ? "#22FFFFFF" : "#11000000"
    }

    Loader {
        id: materialLoader

        anchors.fill: parent

        onStatusChanged: {
            if (status === Loader.Error)
                console.error("[widgets/material] " + root.widgetId
                              + ": ошибка загрузки материала " + root.effectiveMaterial)
        }
    }

    Binding {
        target: materialLoader.item
        property: "colors"
        value: root.effectiveColors
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "radius"
        value: root.materialRadius
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "size"
        value: Qt.size(root.width, root.height)
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "wallpaperSource"
        value: Wallpaper.sourceUrl
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "offsetX"
        value: root.x + root.screenOffsetX
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "offsetY"
        value: root.y + root.screenOffsetY
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "screenWidth"
        value: root.screen ? root.screen.width : 0
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "screenHeight"
        value: root.screen ? root.screen.height : 0
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "editing"
        value: root.editing
        when: materialLoader.status === Loader.Ready
    }

    // --- Контент виджета ---
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

    // --- Редактор (раздел 8 ТЗ) ---
    Rectangle {
        anchors.fill: parent
        z: 5
        visible: root.editing
        color: "transparent"
        radius: root.materialRadius
        border.width: 2
        border.color: root.previewing && !DragController.valid
                      ? Theme.colors.error : Theme.colors.primary
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        z: 10
        visible: root.editing
        enabled: root.editing
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeAllCursor

        onPressed: (mouse) => {
            DragController.startDrag(root, dragArea.mapToItem(null, mouse.x, mouse.y))
            mouse.accepted = true
        }

        onPositionChanged: (mouse) => {
            if (DragController.active && DragController.uid === root.instance.uid)
                DragController.update(dragArea.mapToItem(null, mouse.x, mouse.y))
        }

        onReleased: DragController.finish()
    }

    Repeater {
        model: ["topleft", "top", "topright", "right",
                "bottomright", "bottom", "bottomleft", "left"]

        delegate: MouseArea {
            id: handle

            required property var modelData

            readonly property string edge: modelData
            readonly property bool horizontal: edge.indexOf("left") >= 0
                                                 || edge.indexOf("right") >= 0
            readonly property bool vertical: edge.indexOf("top") >= 0
                                               || edge.indexOf("bottom") >= 0

            width: 14
            height: 14
            z: 20
            visible: root.editing && root.widget
                     && root.widget.sizeSpec && root.widget.sizeSpec.scalable
            cursorShape: horizontal && vertical
                         ? (edge === "topleft" || edge === "bottomright"
                            ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                         : (horizontal ? Qt.SizeHorCursor
                                       : (vertical ? Qt.SizeVerCursor : Qt.ArrowCursor))

            x: edge.indexOf("left") >= 0 ? 0
               : (edge.indexOf("right") >= 0 ? root.width - width
                                              : (root.width - width) / 2)
            y: edge.indexOf("top") >= 0 ? 0
               : (edge.indexOf("bottom") >= 0 ? root.height - height
                                               : (root.height - height) / 2)

            onPressed: (mouse) => {
                DragController.startResize(root, handle.edge,
                                           handle.mapToItem(null, mouse.x, mouse.y))
                mouse.accepted = true
            }

            onPositionChanged: (mouse) => {
                if (DragController.active && DragController.uid === root.instance.uid)
                    DragController.update(handle.mapToItem(null, mouse.x, mouse.y))
            }

            onReleased: DragController.finish()

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.colors.primary
                border.width: 1
                border.color: Theme.colors.onPrimary
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        spacing: 2
        z: 30
        visible: root.editing

        HostButton {
            text: "✕"
            onClicked: {
                EditorState.beginOperation()
                if (root.instance)
                    LayoutStore.removeInstance(root.instance.uid)
            }
        }

        HostButton {
            text: "⚙"
            onClicked: {
                if (root.instance)
                    EditorState.openSettings(root.instance.uid, root.screen.name)
            }
        }
    }
}
