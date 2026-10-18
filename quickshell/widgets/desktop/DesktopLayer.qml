import QtQuick
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
// Редактирование — это режим того же PanelWindow (Overlay + OnDemand), а не
// отдельное окно/слой. Меню, каталог и настройки — обычные Item внутри него.
// Экземпляр создаётся из shell.qml через Variants по Quickshell.screens.
PanelWindow {
    id: root

    readonly property bool editing: EditorState.active
    readonly property bool debugGrid: Config.showGrid

    // Экземпляры виджетов на этом экране. Массив пересоздаётся при изменении
    // раскладки/реестра, поэтому Repeater обновляет карточки.
    property var instances: []
    property var tray: []
    // Геометрия обычного слоя (без бара). В редакторе окно становится на весь
    // экран, но сетка должна остаться прежней.
    property int stableWidth: 0
    property int stableHeight: 0
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
    exclusionMode: root.editing ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0

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
        windowWidth: root.editing && root.stableWidth > 0 ? root.stableWidth : root.width
        windowHeight: root.editing && root.stableHeight > 0 ? root.stableHeight : root.height
    }

    onWidthChanged: {
        if (!root.editing && root.width > 0)
            root.stableWidth = root.width
    }

    onHeightChanged: {
        if (!root.editing && root.height > 0)
            root.stableHeight = root.height
    }

    GridOverlay {
        anchors.fill: parent
        visible: root.debugGrid
        metrics: gridMetrics
    }

    // Затемнение под карточками: в редакторе сетка и виджеты читаются лучше.
    Rectangle {
        anchors.fill: parent
        visible: root.editing
        color: "#66000000"
        z: 1
    }

    Repeater {
        id: hostRepeater

        model: root.instances

        delegate: WidgetHost {
            required property var modelData

            instance: modelData
            metrics: gridMetrics
            screen: root.screen
            editing: root.editing

            onContextRequested: (x, y) => root.openMenu(x, y)
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

    function refreshInstances(): void {
        if (!root.screen || !WidgetRegistry.ready || !LayoutStore.ready) {
            root.instances = []
            root.scheduleMaskSync()
            return
        }
        LayoutStore.ensureScreen(root.screen.name, gridMetrics)
        root.instances = LayoutStore.instancesFor(root.screen.name)
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
                     + ": весь рабочий стол, экземпляров " + hostRepeater.count)
    }

    function openMenu(x: real, y: real): void {
        if (!root.screen)
            return
        desktopMenu.screenName = root.screen.name
        desktopMenu.openAt(x, y)
    }

    function handleMenuAction(name: string): void {
        if (name === "add") {
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
    Rectangle {
        visible: PickerState.active
        z: 56
        x: gridMetrics.originX + PickerState.col * (gridMetrics.cell + gridMetrics.gap)
        y: gridMetrics.originY + PickerState.row * (gridMetrics.cell + gridMetrics.gap)
        width: gridMetrics.pixelWidth(PickerState.cols)
        height: gridMetrics.pixelHeight(PickerState.rows)
        radius: Math.round(gridMetrics.cell * 0.28)
        color: PickerState.valid ? "#114CAF50" : "#11F44336"
        border.width: 2
        border.color: PickerState.valid ? "#CC4CAF50" : "#CCF44336"
        enabled: false
    }

    // Призрак будущего положения/размера (раздел 8.3 ТЗ).
    Rectangle {
        visible: DragController.active
        z: 55
        x: gridMetrics.originX + DragController.col * (gridMetrics.cell + gridMetrics.gap)
        y: gridMetrics.originY + DragController.row * (gridMetrics.cell + gridMetrics.gap)
        width: gridMetrics.pixelWidth(DragController.cols)
        height: gridMetrics.pixelHeight(DragController.rows)
        radius: Math.round(gridMetrics.cell * 0.28)
        color: DragController.valid ? "#114CAF50" : "#11F44336"
        border.width: 2
        border.color: DragController.valid ? "#CC4CAF50" : "#CCF44336"
        enabled: false
    }

    // Верхняя панель редактора (раздел 8.2 ТЗ).
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 6
        z: 100
        visible: root.editing

        HostButton {
            text: "+"
            onClicked: EditorState.openPicker(root.screen.name)
        }

        HostButton {
            text: "Готово"
            onClicked: EditorState.exitCommit()
        }

        HostButton {
            text: "Отмена"
            onClicked: EditorState.cancel()
        }
    }

    // Лоток «Не помещается». Перетаскивание из него появится вместе с пикером;
    // сейчас можно вернуть виджет в первое свободное место или удалить.
    Rectangle {
        id: trayPanel

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: Math.min(280, parent.width - 24)
        height: Math.min(240, trayColumn.implicitHeight + 16)
        radius: 12
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.outline
        visible: root.editing && root.tray.length > 0
        z: 95

        Column {
            id: trayColumn

            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                color: Theme.colors.onSurface
                font.pixelSize: 12
                font.bold: true
                text: "Не помещается (" + root.tray.length + ")"
            }

            Repeater {
                model: root.tray

                delegate: Row {
                    id: trayRow

                    required property var modelData

                    width: trayColumn.width
                    spacing: 4

                    Text {
                        width: Math.max(40, trayRow.width - 96)
                        color: Theme.colors.onSurfaceVariant
                        font.pixelSize: 11
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
