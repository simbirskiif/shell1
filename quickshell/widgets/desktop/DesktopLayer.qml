pragma ComponentBehavior: Bound

import QtQuick
import "../../components/expressive"
import "../../singletons"
import Quickshell
import Quickshell.Wayland
import "../core"
import "../editor"

// Слой рабочего стола на одном экране (раздел 2 ТЗ).
//
// Окно занимает доступную область экрана и живёт на слое Bottom: над обоями,
// под обычными окнами. В обычном режиме клавиатурный фокус не берётся, но
// область ввода покрывает весь рабочий стол — это единственный слой виджетов,
// поэтому ПКМ по пустому месту открывает меню, а не уходит в другое окно.
//
// Редактирование — это режим того же PanelWindow: размер и позиция не
// меняются, бар остаётся сверху. Меню, каталог и настройки — обычные Item
// внутри этого же окна, без второго окна и без затемнения всего экрана.
// Экземпляр создаётся из shell.qml через Variants по Quickshell.screens.
PanelWindow {
    id: root

    readonly property bool editing: EditorState.active
    readonly property bool debugGrid: Config.showGrid

    // Стабильный список uid: при добавлении/удалении одного виджета
    // Repeater не пересоздаёт остальные карточки (иначе все они летели бы
    // из левого верхнего угла). Сами объекты берутся из LayoutStore.
    ListModel {
        id: instanceModel
    }
    property var tray: []
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
    // сам сдвигает её ниже бара. Этот режим не меняется при входе в редактор,
    // поэтому окно не прыгает по размеру и не перекрывает бар.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    // В обычном режиме — под окнами, в редакторе — поверх них. Это тот же
    // PanelWindow и тот же namespace; второго окна/слоя для редактора нет.
    // exclusionMode выше не меняется, поэтому размер остаётся прежним.
    WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:widgets-desktop"
    WlrLayershell.keyboardFocus: root.editing
                                  ? WlrKeyboardFocus.OnDemand
                                  : WlrKeyboardFocus.None
    WlrLayershell.focusable: root.editing

    // Ввод всегда покрывает весь рабочий стол: виджеты — единственный слой,
    // поэтому ПКМ по пустому месту должен открывать контекстное меню.
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

        model: instanceModel

        delegate: WidgetHost {
            required property string instanceUid

            uid: instanceUid
            instance: LayoutStore.findInstance(instanceUid)
            metrics: gridMetrics
            screen: root.screen
            editing: root.editing
            widgetsBackdrop: widgetBackdrop

            onContextRequested: (x, y, uid) => root.openMenu(x, y, uid)
        }

        onItemAdded: root.scheduleMaskSync()
        onItemRemoved: root.scheduleMaskSync()
    }

    // Текстура «все виджеты, кроме перетаскиваемого». Драgged host получает
    // её в материал, поэтому glass/liquid показывает соседние карточки, а не
    // только обои. Копии лежат под настоящими карточками, так что в обычном
    // режиме их не видно.
    Item {
        id: widgetBackdrop

        anchors.fill: parent
        z: -10
        visible: DragController.active

        Repeater {
            model: hostRepeater.count

            delegate: ShaderEffectSource {
                required property int index

                readonly property var sourceHost: hostRepeater.itemAt(index)

                sourceItem: sourceHost
                x: sourceHost ? sourceHost.x : 0
                y: sourceHost ? sourceHost.y : 0
                width: sourceHost ? sourceHost.width : 0
                height: sourceHost ? sourceHost.height : 0
                visible: sourceHost !== null && sourceHost.uid !== DragController.uid
                live: true
                hideSource: false
            }
        }
    }

    Connections {
        target: WidgetRegistry

        function onRegistryChanged() {
            // Уже созданные карточки сами следят за widgetById; пересобирать
            // их нужно только пока раскладка ещё не создана.
            if (instanceModel.count === 0 && WidgetRegistry.ready)
                root.refreshInstances()
        }
    }

    Connections {
        target: LayoutStore

        function onLayoutChanged() {
            root.refreshInstances()
        }
    }

    Connections {
        target: gridMetrics

        function onColsChanged() {
            root.scheduleGridRefresh()
        }

        function onRowsChanged() {
            root.scheduleGridRefresh()
        }

        function onCellChanged() {
            root.scheduleGridRefresh()
        }
    }

    Connections {
        target: EditorState

        function onActiveChanged() {
            desktopMenu.close()
            if (!EditorState.active) {
                DragController.cancel()
                PickerState.cancel()
            }
            root.scheduleMaskSync()
            if (EditorState.active)
                keys.forceActiveFocus()
        }
    }

    Timer {
        id: gridRefreshTimer
        interval: 280
        repeat: false
        onTriggered: root.refreshInstances()
    }

    function scheduleGridRefresh(): void {
        gridRefreshTimer.restart()
    }

    function rowFor(uid: string): int {
        for (let i = 0; i < instanceModel.count; i++) {
            if (instanceModel.get(i).instanceUid === uid)
                return i
        }
        return -1
    }

    function refreshInstances(): void {
        if (!root.screen || !WidgetRegistry.ready || !LayoutStore.ready) {
            instanceModel.clear()
            root.scheduleMaskSync()
            return
        }
        LayoutStore.ensureScreen(root.screen.name, gridMetrics)
        const list = LayoutStore.instancesFor(root.screen.name)
        const wanted = ({})
        for (const instance of list)
            wanted[instance.uid] = true
        for (let i = instanceModel.count - 1; i >= 0; i--) {
            if (!wanted[instanceModel.get(i).instanceUid])
                instanceModel.remove(i)
        }
        for (const instance of list) {
            if (root.rowFor(instance.uid) < 0)
                instanceModel.append({ instanceUid: instance.uid })
        }
        root.tray = LayoutStore.trayFor(root.screen.name)
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

        const region = root.contentItem
            ? maskRegionComponent.createObject(maskRegion, { item: root.contentItem })
            : maskRegionComponent.createObject(maskRegion, {
                  x: 0, y: 0,
                  width: Math.max(1, root.width),
                  height: Math.max(1, root.height)
              })
        if (region) {
            maskRegion.regions.push(region)
            root._maskRegions.push(region)
        }
        maskRegion.changed()
        console.info("[widgets/mask] " + gridMetrics.screenName
                     + ": весь рабочий стол, экземпляров " + instanceModel.count)
    }

    function openMenu(x: real, y: real, uid: string): void {
        if (!root.screen)
            return
        desktopMenu.screenName = root.screen.name
        desktopMenu.targetUid = uid || ""
        desktopMenu.openAt(x, y)
    }

    function handleMenuAction(name: string): void {
        if (name === "widget-settings") {
            if (desktopMenu.targetUid.length > 0)
                EditorState.openSettings(desktopMenu.targetUid, root.screen.name)
        } else if (name === "add") {
            EditorState.openPicker(root.screen.name)
        } else if (name === "global") {
            EditorState.openGlobalSettings(root.screen.name)
        } else if (name === "edit") {
            EditorState.enter()
        } else if (name === "commit") {
            EditorState.exitCommit()
        } else if (name === "cancel") {
            EditorState.cancel()
        }
    }

    // Клики по пустому рабочему столу: ПКМ открывает меню, ЛКМ закрывает его
    // и снимает выделение. Слой под виджетами, поэтому интерактив карточек
    // получает события первым.
    MouseArea {
        anchors.fill: parent
        z: -20
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.openMenu(mouse.x, mouse.y)
            } else {
                desktopMenu.close()
                EditorState.clearSelection()
            }
        }
    }

    // Призрак drag-and-drop из каталога (раздел 8.5 ТЗ).
    // Expressive: форма и цвет читают валидность (squircle/primary-контейнер
    // против burst/error), а позиция и размер доезжают на пружине.
    Item {
        id: pickerGhost

        visible: PickerState.active
        z: 56
        x: gridMetrics.originX + PickerState.col * (gridMetrics.cell + gridMetrics.gap)
        y: gridMetrics.originY + PickerState.row * (gridMetrics.cell + gridMetrics.gap)
        width: gridMetrics.pixelWidth(PickerState.cols)
        height: gridMetrics.pixelHeight(PickerState.rows)
        enabled: false

        Behavior on x { SpringSpatial {} }
        Behavior on y { SpringSpatial {} }
        Behavior on width { SpringSpatial {} }
        Behavior on height { SpringSpatial {} }

        MorphShape {
            anchors.fill: parent
            shape: PickerState.valid ? "squircle" : "burst"
            modulation: 0.34
            color: PickerState.valid
                   ? Theme.withAlpha(Theme.primaryContainer, 0.55)
                   : Theme.withAlpha(Theme.errorContainer, 0.6)
            borderWidth: 2
            borderColor: PickerState.valid ? Theme.primary : Theme.error
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    // Призрак будущего положения/размера (раздел 8.3 ТЗ).
    Item {
        id: dragGhost

        visible: DragController.active
        z: 55
        x: gridMetrics.originX + DragController.col * (gridMetrics.cell + gridMetrics.gap)
        y: gridMetrics.originY + DragController.row * (gridMetrics.cell + gridMetrics.gap)
        width: gridMetrics.pixelWidth(DragController.cols)
        height: gridMetrics.pixelHeight(DragController.rows)
        enabled: false

        // Сетка квантует позицию по клеткам, но призрак едет к ней пружиной —
        // жест читается как «магнит», а не как прыжки по дискретам.
        Behavior on x { SpringSpatial {} }
        Behavior on y { SpringSpatial {} }
        Behavior on width { SpringSpatial {} }
        Behavior on height { SpringSpatial {} }

        MorphShape {
            anchors.fill: parent
            shape: DragController.valid ? "squircle" : "burst"
            modulation: 0.34
            color: DragController.valid
                   ? Theme.withAlpha(Theme.primaryContainer, 0.55)
                   : Theme.withAlpha(Theme.errorContainer, 0.6)
            borderWidth: 2
            borderColor: DragController.valid ? Theme.primary : Theme.error
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    // Верхняя панель редактора (раздел 8.2 ТЗ) — Expressive: крупный FAB
    // «добавить» и кнопки-пилюли 44. Формы морфятся на hover/press
    // (cookie → squircle), движение — пружины, а не длительности.
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.space.md
        spacing: Theme.space.sm
        z: 100
        visible: root.editing

        ExpressiveFab {
            icon: "+"
            size: 48
            tone: "primary"
            shape: "cookie"
            hoverShape: "squircle"
            onClicked: EditorState.openPicker(root.screen.name)
        }

        Item {
            id: commitButton

            width: commitLabel.implicitWidth + Theme.space.xl * 2
            height: 44
            scale: commitHover.pressed ? 0.94 : (commitHover.containsMouse ? 1.04 : 1)
            Behavior on scale { SpringSpatial {} }

            MorphShape {
                anchors.fill: parent
                shape: commitHover.pressed ? "squircle" : "pill"
                modulation: 0.4
                color: commitHover.containsMouse
                       ? Theme.mix(Theme.primary, Theme.scheme.onPrimary, Theme.stateHover)
                       : Theme.primary
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                id: commitLabel

                anchors.centerIn: parent
                text: "✓ Готово"
                color: Theme.scheme.onPrimary
                font: Theme.typeEmphasizedLabelLarge
                scale: commitHover.pressed ? 0.96 : 1
                Behavior on scale { SpringSpatialFast {} }
            }

            MouseArea {
                id: commitHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: EditorState.exitCommit()
            }
        }

        Item {
            id: cancelButton

            width: cancelLabel.implicitWidth + Theme.space.xl * 2
            height: 44
            scale: cancelHover.pressed ? 0.94 : (cancelHover.containsMouse ? 1.04 : 1)
            Behavior on scale { SpringSpatial {} }

            MorphShape {
                anchors.fill: parent
                shape: cancelHover.pressed ? "squircle" : "pill"
                modulation: 0.4
                color: cancelHover.containsMouse
                       ? Theme.mix(Theme.secondaryContainer, Theme.scheme.onSecondaryContainer,
                                   Theme.stateHover)
                       : Theme.secondaryContainer
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                id: cancelLabel

                anchors.centerIn: parent
                text: "✕ Отмена"
                color: Theme.scheme.onSecondaryContainer
                font: Theme.typeEmphasizedLabelLarge
                scale: cancelHover.pressed ? 0.96 : 1
                Behavior on scale { SpringSpatialFast {} }
            }

            MouseArea {
                id: cancelHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: EditorState.cancel()
            }
        }
    }

    // Лоток «Не помещается». Перетаскивание из него появится вместе с пикером;
    // сейчас можно вернуть виджет в первое свободное место или удалить.
    // Expressive: крупный squircle-контейнер surface-container-high; строки
    // сгруппированы цветом и формой кнопок, без тонких разделителей.
    Item {
        id: trayPanel

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space.md
        width: Math.min(280, parent.width - Theme.space.xl)
        height: Math.min(240, trayColumn.implicitHeight + Theme.space.lg)
        visible: root.editing && root.tray.length > 0
        z: 95

        MorphShape {
            anchors.fill: parent
            shape: "squircle"
            modulation: 0.3
            color: Theme.menuSurfaceSolid
            borderWidth: 0
        }

        Column {
            id: trayColumn

            anchors.fill: parent
            anchors.margins: Theme.space.sm
            spacing: Theme.space.xs

            Text {
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedTitleMedium
                text: "Не помещается (" + root.tray.length + ")"
            }

            Repeater {
                model: root.tray

                delegate: Row {
                    id: trayRow

                    required property var modelData

                    width: trayColumn.width
                    spacing: Theme.space.xs

                    Text {
                        width: Math.max(40, trayRow.width - 96)
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodySmall
                        elide: Text.ElideRight
                        text: trayRow.modelData.name || trayRow.modelData.id
                    }

                    HostButton {
                        text: "↩"
                        onClicked: {
                            EditorState.beginOperation()
                            if (!LayoutStore.restoreTray(trayRow.modelData.uid,
                                                         root.screen.name, gridMetrics))
                                console.info("[widgets/editor] нет места для "
                                             + trayRow.modelData.id)
                        }
                    }

                    HostButton {
                        text: "✕"
                        onClicked: {
                            EditorState.beginOperation()
                            LayoutStore.removeInstance(trayRow.modelData.uid)
                        }
                    }
                }
            }
        }
    }

    WidgetPicker {
        screen: root.screen
        metrics: gridMetrics
    }

    WidgetSettingsPopup {
        uid: EditorState.settingsUid
        screen: root.screen
        metrics: gridMetrics
    }

    WidgetsGlobalPopup {
        screen: root.screen
    }

    // Затемняющая подложка меню: закрывает его по клику вне панели, но не
    // создаёт отдельного слоя.
    MouseArea {
        anchors.fill: parent
        visible: desktopMenu.opened
        z: 200
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: desktopMenu.close()
    }

    DesktopContextMenu {
        id: desktopMenu
        editing: root.editing
        onAction: (name) => root.handleMenuAction(name)
    }

    // Esc / Ctrl+Z / Ctrl+Shift+Z. Фокус получает только редактор.
    Item {
        id: keys

        anchors.fill: parent
        z: 220
        enabled: root.editing
        focus: root.editing

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (desktopMenu.opened)
                    desktopMenu.close()
                else if (EditorState.settingsUid.length > 0)
                    EditorState.closeSettings()
                else if (EditorState.globalOpen)
                    EditorState.closeGlobalSettings()
                else if (EditorState.pickerOpen)
                    EditorState.closePicker()
                else
                    EditorState.exitCommit()
                event.accepted = true
            } else if (event.key === Qt.Key_Z
                       && (event.modifiers & Qt.ControlModifier)) {
                if (event.modifiers & Qt.ShiftModifier)
                    EditorState.redo()
                else
                    EditorState.undo()
                event.accepted = true
            }
        }
    }

    Component.onCompleted: {
        console.info("[widgets/layer] desktop layer created for " + gridMetrics.screenName)
        root.refreshInstances()
    }
}
