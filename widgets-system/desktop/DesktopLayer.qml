import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Слой рабочего стола на одном экране (раздел 2 ТЗ).
//
// Окно занимает доступную область экрана и живёт на слое Bottom: над обоями,
// под обычными окнами. В обычном режиме клавиатурный фокус не берётся, а
// область ввода строится по видимым виджетам. Пока виджетов нет, маска
// пустая — клики проходят в окна под слоем.
//
// Экземпляр создаётся из shell.qml через Variants по Quickshell.screens.
PanelWindow {
    id: root

    readonly property bool debugGrid: Config.showGrid

    // Экземпляры виджетов на этом экране. Массив пересоздаётся при изменении
    // раскладки/реестра, поэтому Repeater обновляет карточки.
    property var instances: []
    property var _maskRegions: []
    property bool _maskScheduled: false

    visible: true
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Слой не резервирует место (exclusiveZone 0), но exclusionMode Normal
    // оставляет поверхность в свободной от чужих панелей области: композитор
    // сам сдвигает её ниже бара, а GridMetrics считает сетку по фактическому
    // размеру окна.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:widgets-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.focusable: false

    // Область ввода строится из прямоугольников видимых карточек виджетов.
    // Клики вне карточек проходят в окна под слоем; в режиме редактирования
    // маска будет расширена на весь экран (этап 5).
    mask: Region {
        id: maskRegion
    }

    Component {
        id: maskRegionComponent
        Region {}
    }

    GridMetrics {
        id: gridMetrics
        screen: root.screen
        windowWidth: root.width
        windowHeight: root.height
    }

    GridOverlay {
        anchors.fill: parent
        visible: root.debugGrid
        metrics: gridMetrics
    }

    Repeater {
        id: hostRepeater

        model: root.instances

        delegate: WidgetHost {
            required property var modelData

            instance: modelData
            metrics: gridMetrics
            screen: root.screen
        }

        onItemAdded: root.scheduleMaskSync()
        onItemRemoved: root.scheduleMaskSync()
    }

    Connections {
        target: WidgetRegistry

        function onRegistryChanged() {
            // Уже созданные карточки сами следят за widgetById; пересобирать
            // их нужно только пока раскладка ещё не создана.
            if (root.instances.length === 0 && WidgetRegistry.ready)
                root.refreshInstances()
        }
    }

    Connections {
        target: LayoutStore

        function onLayoutChanged() {
            root.refreshInstances()
        }
    }

    function refreshInstances(): void {
        if (!root.screen || !WidgetRegistry.ready) {
            root.instances = []
            root.scheduleMaskSync()
            return
        }
        LayoutStore.ensureScreen(root.screen.name, gridMetrics)
        root.instances = LayoutStore.instancesFor(root.screen.name)
        root.scheduleMaskSync()
    }

    function scheduleMaskSync(): void {
        if (root._maskScheduled)
            return
        root._maskScheduled = true
        Qt.callLater(root.syncMask)
    }

    function syncMask(): void {
        root._maskScheduled = false
        while (maskRegion.regions.length > 0) {
            const region = maskRegion.regions.pop()
            if (region)
                region.destroy()
        }
        root._maskRegions = []

        for (let i = 0; i < hostRepeater.count; i++) {
            const host = hostRepeater.itemAt(i)
            if (!host || !host.visible)
                continue
            const region = maskRegionComponent.createObject(maskRegion, { item: host })
            if (region) {
                maskRegion.regions.push(region)
                root._maskRegions.push(region)
            }
        }
        maskRegion.changed()
        console.info("[widgets/mask] " + gridMetrics.screenName + ": "
                     + root._maskRegions.length + " областей, экземпляров "
                     + hostRepeater.count)
    }

    Component.onCompleted: {
        console.info("[widgets/layer] desktop layer created for " + gridMetrics.screenName)
        root.refreshInstances()
    }
}
