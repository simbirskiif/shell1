pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../singletons"
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

    // uid приходит из стабильной модели DesktopLayer; instance резолвится
    // заново при изменении раскладки, не пересоздавая карточку.
    property string uid: ""

    property bool editing: false
    property bool preview: false
    property var widgetsBackdrop: null

    signal contextRequested(real x, real y, string uid)

    // Уникальный стартовый токен: новый экземпляр не должен попасть в
    // QML-кеш старой (иногда уже сломанной) версии файла с ?v=0.
    property int reloadToken: 1 + Math.floor(Math.random() * 2147483646)
    property bool _initialized: false

    // Локальные копии переопределений экземпляра: LayoutStore меняет поля
    // объекта, а не сам объект, поэтому нужен явный refresh при
    // instanceChanged.
    property string instanceMaterial: ""
    property string instanceColorMode: ""
    property real instanceDim: NaN
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
    property int displayCol: root.instance ? root.instance.col : 0
    property int displayRow: root.instance ? root.instance.row : 0
    property int displayCols: root.instance ? root.instance.cols : 1
    property int displayRows: root.instance ? root.instance.rows : 1

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

    readonly property bool selected: root.editing && root.instance
                                     && EditorState.selectedUid === root.instance.uid
    readonly property bool scalable: root.widget && root.widget.sizeSpec
                                     && root.widget.sizeSpec.scalable
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

    readonly property real padding: Theme.space.lg
    // Радиус подложки — форма M3 по размеру карточки: маленькая — large,
    // крупная — extra-large. Материал получает уже готовый радиус, поэтому
    // glass/liquid остаются как есть и просто следуют форме карточки.
    readonly property int materialRadius:
        Math.min(root.width, root.height) < 160 ? Theme.shape.lg : Theme.shape.xl
    // Смещение окна слоя внутри экрана: верхняя/боковая панель композитора.
    readonly property real screenOffsetX:
        root.screen ? Math.max(0, root.screen.width - root.metrics.areaWidth) : 0
    readonly property real screenOffsetY:
        root.screen ? Math.max(0, root.screen.height - root.metrics.areaHeight) : 0

    // Палитру и материал назначает система. Виджет получает готовые
    // ctx.colors/ctx.material; манифест не может сузить выбор. Если автору
    // нужны собственные цвета, он просто не использует ctx.colors.
    readonly property string effectiveColorMode: {
        let requested = root.instanceColorMode.length > 0
                      ? root.instanceColorMode : Config.defaultColorMode
        if (requested === "widget")
            requested = "neutral"
        return requested === "neutral" ? "neutral" : "accent"
    }

    readonly property var effectiveColors:
        Theme.colorsFor(root.effectiveColorMode)
    readonly property real effectiveDim:
        Number.isFinite(root.instanceDim) ? root.instanceDim
                                         : Config.defaultMaterialDim

    readonly property string effectiveMaterial: {
        const requested = root.instanceMaterial.length > 0
                        ? root.instanceMaterial : Config.defaultMaterial
        if (MaterialRegistry.materialById(requested))
            return requested
        if (MaterialRegistry.materialById("glass"))
            return "glass"
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
    // Перетаскиваемый виджет должен быть выше соседей и призрака-рамки:
    // стекло тогда читает то, что находится под ним, а не прячется за слоем.
    z: root.dragActive ? 100 : 0
    // Карточка клипает своё содержимое; хост не клипает, чтобы круглые
    // кнопки редактора могли чуть выходить за границу карточки.
    clip: false

    // Перемещение/ресайз после отпускания — standard decelerate M3.
    Behavior on x {
        enabled: !root.dragActive
        NumberAnimation {
            duration: Theme.motionShort4
            easing.bezierCurve: Theme.curveStandardDecelerate
        }
    }
    Behavior on y {
        enabled: !root.dragActive
        NumberAnimation {
            duration: Theme.motionShort4
            easing.bezierCurve: Theme.curveStandardDecelerate
        }
    }
    Behavior on width {
        enabled: !root.dragActive
        NumberAnimation {
            duration: Theme.motionShort4
            easing.bezierCurve: Theme.curveStandardDecelerate
        }
    }
    Behavior on height {
        enabled: !root.dragActive
        NumberAnimation {
            duration: Theme.motionShort4
            easing.bezierCurve: Theme.curveStandardDecelerate
        }
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
        root.instanceDim = current && Number.isFinite(current.dim)
                          ? current.dim : NaN
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
            dim: root.effectiveDim,
            widgetsBackdrop: root.dragActive ? root.widgetsBackdrop : null,
            localX: root.x,
            localY: root.y,
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

    onDragActiveChanged: {
        // Binding на item материала обновляется не в том же кадре, что и
        // начало drag; синхронизируем текстуру соседних виджетов явно.
        dragBackdropSync.restart()
    }

    Timer {
        id: dragBackdropSync
        interval: 16
        repeat: false
        onTriggered: {
            if (!materialLoader.item)
                return
            materialLoader.item.widgetsBackdrop =
                root.dragActive ? root.widgetsBackdrop : null
        }
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
        fontFamilyData: Theme.fontFamily
        materialDimData: root.effectiveDim
        backdropData: backdropProbe.info

        onSettingRequested: (key, value) => {
            if (root.instance)
                LayoutStore.setSetting(root.instance.uid, key, value)
        }
    }

    // Проба обоев под карточкой. Живёт рядом с контекстом, а не внутри
    // материала: виджет получает готовые цвета через ctx.backdrop.
    BackdropProbe {
        id: backdropProbe

        source: Wallpaper.sourceUrl
        screenWidth: root.screen ? root.screen.width : 0
        screenHeight: root.screen ? root.screen.height : 0
        rectX: root.x + root.screenOffsetX
        rectY: root.y + root.screenOffsetY
        rectWidth: root.width
        rectHeight: root.height
        fallbackColor: root.effectiveColors && root.effectiveColors.surface
                       ? root.effectiveColors.surface : Theme.surface
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

        function onLayoutChanged() {
            if (root.uid.length === 0)
                return
            const resolved = LayoutStore.findInstance(root.uid)
            if (resolved !== root.instance)
                root.instance = resolved
            root.refreshGeometry()
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

    // Визуальная карточка. В редакторе чуть уменьшается, чтобы кнопки
    // управления могли выйти за её границу и не закрывать контент.
    Item {
        id: card

        anchors.fill: parent
        scale: root.editing ? 0.95 : 1
        transformOrigin: Item.Center
        clip: true

        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionShort4
                easing.bezierCurve: Theme.curveStandardDecelerate
            }
        }

    // --- Материал подложки (раздел 6.1 ТЗ) ---
    Rectangle {
        id: materialFallback

        anchors.fill: parent
        visible: materialLoader.status !== Loader.Ready
        radius: root.materialRadius
        color: Theme.colors.surface
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
        property: "dim"
        value: root.effectiveDim
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "widgetsBackdrop"
        value: root.dragActive ? root.widgetsBackdrop : null
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "localX"
        value: root.x
        when: materialLoader.status === Loader.Ready
    }

    Binding {
        target: materialLoader.item
        property: "localY"
        value: root.y
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
    // Выделение — скруглённый контур по форме карточки, без квадратной рамки
    // и без отдельных квадратных ручек. Тянуть за контур = менять размер.
    Shape {
        id: selectionOutline

        anchors.fill: parent
        anchors.margins: 1
        z: 15
        visible: root.editing && root.selected
        asynchronous: false

        readonly property real r: Math.max(0, Math.min(root.materialRadius,
                                          Math.min(width, height) / 2))

        ShapePath {
            fillColor: "transparent"
            // Активное выделение — primary: служебный зелёный здесь не роль M3.
            strokeColor: Theme.primary
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            startX: selectionOutline.r
            startY: 0

            PathLine { x: selectionOutline.width - selectionOutline.r; y: 0 }
            PathArc {
                x: selectionOutline.width; y: selectionOutline.r
                radiusX: selectionOutline.r; radiusY: selectionOutline.r
                direction: PathArc.Clockwise
            }
            PathLine { x: selectionOutline.width; y: selectionOutline.height - selectionOutline.r }
            PathArc {
                x: selectionOutline.width - selectionOutline.r; y: selectionOutline.height
                radiusX: selectionOutline.r; radiusY: selectionOutline.r
                direction: PathArc.Clockwise
            }
            PathLine { x: selectionOutline.r; y: selectionOutline.height }
            PathArc {
                x: 0; y: selectionOutline.height - selectionOutline.r
                radiusX: selectionOutline.r; radiusY: selectionOutline.r
                direction: PathArc.Clockwise
            }
            PathLine { x: 0; y: selectionOutline.r }
            PathArc {
                x: selectionOutline.r; y: 0
                radiusX: selectionOutline.r; radiusY: selectionOutline.r
                direction: PathArc.Clockwise
            }
        }
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
            if (root.instance)
                EditorState.select(root.instance.uid)
            DragController.startDrag(root, dragArea.mapToItem(null, mouse.x, mouse.y))
            mouse.accepted = true
        }

        onPositionChanged: (mouse) => {
            if (DragController.active && DragController.uid === root.instance.uid)
                DragController.update(dragArea.mapToItem(null, mouse.x, mouse.y))
        }

        onReleased: DragController.finish()
    }

    // Зоны вдоль всего зелёного контура. Углы — диагональный ресайз, стороны —
    // по одной оси. Отдельных видимых квадратов-ручек больше нет.
    Repeater {
        model: ["topleft", "top", "topright", "right",
                "bottomright", "bottom", "bottomleft", "left"]

        delegate: MouseArea {
            id: resizeZone

            required property var modelData

            readonly property string edge: modelData
            readonly property int band: 11
            readonly property int corner: 20
            readonly property bool horizontal: edge.indexOf("left") >= 0
                                                 || edge.indexOf("right") >= 0
            readonly property bool vertical: edge.indexOf("top") >= 0
                                               || edge.indexOf("bottom") >= 0
            readonly property bool cornerZone: horizontal && vertical

            z: 20
            visible: root.scalable
            cursorShape: cornerZone
                         ? (edge === "topleft" || edge === "bottomright"
                            ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                         : (horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor)

            width: cornerZone ? corner
                   : (horizontal ? band : Math.max(1, card.width - 2 * corner))
            height: cornerZone ? corner
                    : (vertical ? band : Math.max(1, card.height - 2 * corner))
            x: horizontal ? (edge.indexOf("left") >= 0 ? 0 : card.width - width)
                          : corner
            y: vertical ? (edge.indexOf("top") >= 0 ? 0 : card.height - height)
                        : corner

            onPressed: (mouse) => {
                if (root.instance)
                    EditorState.select(root.instance.uid)
                DragController.startResize(root, resizeZone.edge,
                                           resizeZone.mapToItem(null, mouse.x, mouse.y))
                mouse.accepted = true
            }

            onPositionChanged: (mouse) => {
                if (DragController.active && DragController.uid === root.instance.uid)
                    DragController.update(resizeZone.mapToItem(null, mouse.x, mouse.y))
            }

            onReleased: DragController.finish()
        }
    }

    }

    // ПКМ по виджету открывает то же меню слоя, что и ПКМ по пустому месту.
    // Кнопка только правая, поэтому левый интерактив виджета не страдает.
    MouseArea {
        anchors.fill: parent
        z: 40
        acceptedButtons: Qt.RightButton

        onClicked: (mouse) => {
            if (root.instance && root.editing)
                EditorState.select(root.instance.uid)
            const point = mapToItem(null, mouse.x, mouse.y)
            root.contextRequested(point.x, point.y,
                                  root.instance ? root.instance.uid : "")
        }
    }

    Row {
        id: controls

        anchors.top: card.top
        anchors.topMargin: -13
        anchors.right: card.right
        anchors.rightMargin: -5
        spacing: 4
        z: 30
        visible: root.editing

        HostIconButton {
            text: "⚙"
            onClicked: {
                if (root.instance)
                    EditorState.openSettings(root.instance.uid, root.screen.name)
            }
        }

        HostIconButton {
            text: "✕"
            onClicked: {
                EditorState.beginOperation()
                if (root.instance)
                    LayoutStore.removeInstance(root.instance.uid)
            }
        }
    }
}
