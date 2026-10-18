pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Раскладка экземпляров виджетов (раздел 7 ТЗ).
//
// Состояние хранится в $XDG_STATE_HOME/quickshell/widgets/layout.json через
// FileView + JsonAdapter. Запись атомарная, с задержкой 500 мс. Для каждого
// экрана хранится текущая сигнатура сетки ("cols x rows") и отдельные
// раскладки известных сигнатур; при переходе на новую сигнатуру позиции и
// размеры масштабируются, размеры приводятся к допустимым, коллизии
// разрешаются поиском ближайшего свободного места, не поместившиеся
// экземпляры уходят в tray.
Singleton {
    id: root

    // screenName -> { signature, grid, widgets, tray, signatures }
    property var screens: ({})
    property bool ready: false

    signal layoutChanged()
    signal instanceChanged(string uid)

    readonly property string stateBase: {
        const xdg = Quickshell.env("XDG_STATE_HOME")
        const home = Quickshell.env("HOME") || ""
        return (xdg && xdg.length > 0 ? xdg : home + "/.local/state") + "/quickshell"
    }
    readonly property string statePath: root.stateBase + "/widgets/layout.json"

    property bool _loading: false
    property int _nextUid: 1
    property double _lastSaveAt: 0

    Process {
        command: ["mkdir", "-p", root.stateBase + "/widgets"]
        running: true
    }

    FileView {
        id: stateFile

        path: root.statePath
        watchChanges: true
        atomicWrites: true
        preload: true
        printErrors: false

        onLoaded: root.loadState()
        onLoadFailed: root.stateMissing()
        onFileChanged: {
            if (Date.now() - root._lastSaveAt < 1200)
                return
            reload()
        }

        JsonAdapter {
            id: state

            property int schema: 1
            property JsonObject defaults: JsonObject {
                property string material: "glass"
                property string colorMode: "accent"
            }
            property var screens: ({})
        }
    }

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: root.saveState()
    }

    // --- Чтение ---
    function instancesFor(screenName: string): var {
        const entry = root.screens[screenName]
        return entry && entry.widgets ? entry.widgets.slice() : []
    }

    function trayFor(screenName: string): var {
        const entry = root.screens[screenName]
        return entry && entry.tray ? entry.tray.slice() : []
    }

    function signatureFor(screenName: string): string {
        const entry = root.screens[screenName]
        return entry ? (entry.signature || "") : ""
    }

    function findInstance(uid: string): var {
        const located = root.locate(uid)
        return located ? located.instance : null
    }

    function locate(uid: string): var {
        for (const screenName in root.screens) {
            const entry = root.screens[screenName]
            const lists = [entry.widgets, entry.tray]
            for (const list of lists) {
                if (!list)
                    continue
                for (const item of list) {
                    if (item.uid === uid)
                        return { instance: item, list: list, entry: entry, screen: screenName }
                }
            }
            for (const signature in entry.signatures || {}) {
                const layout = entry.signatures[signature]
                const inner = [layout.widgets, layout.tray]
                for (const list of inner) {
                    if (!list)
                        continue
                    for (const item of list) {
                        if (item.uid === uid)
                            return { instance: item, list: list, entry: entry, screen: screenName }
                    }
                }
            }
        }
        return null
    }

    // --- Сетка и миграция ---
    function ensureScreen(screenName: string, metrics: var): void {
        if (!root.ready || !WidgetRegistry.ready || !metrics
            || metrics.cols < 2 || metrics.rows < 2 || metrics.cell < 16)
            return

        const signature = metrics.cols + "x" + metrics.rows
        let entry = root.screens[screenName]

        if (!entry) {
            const widgets = root.seedInstances(metrics)
            const layout = {
                grid: { cols: metrics.cols, rows: metrics.rows },
                widgets: widgets,
                tray: []
            }
            entry = {
                signature: signature,
                grid: layout.grid,
                widgets: layout.widgets,
                tray: layout.tray,
                signatures: ({})
            }
            entry.signatures[signature] = layout
            root.screens[screenName] = entry
            root.reindex()
            console.info("[widgets/layout] создана раскладка " + screenName
                         + " " + signature + ": " + widgets.length + " экземпляров")
            root.layoutChanged()
            root.scheduleSave()
            return
        }

        root.normalizeEntry(entry)
        if (entry.signature === signature) {
            entry.grid = { cols: metrics.cols, rows: metrics.rows }
            return
        }

        const target = entry.signatures[signature]
        if (target) {
            entry.signature = signature
            entry.grid = target.grid
            entry.widgets = target.widgets
            entry.tray = target.tray
            console.info("[widgets/layout] восстановлена раскладка " + screenName
                         + " " + signature)
        } else {
            const migrated = root.migrate(entry.widgets, entry.grid, metrics)
            const layout = {
                grid: { cols: metrics.cols, rows: metrics.rows },
                widgets: migrated.widgets,
                tray: migrated.tray
            }
            entry.signatures[signature] = layout
            entry.signature = signature
            entry.grid = layout.grid
            entry.widgets = layout.widgets
            entry.tray = layout.tray
            console.info("[widgets/layout] миграция " + screenName + " -> " + signature
                         + ": " + layout.widgets.length + " на сетке, "
                         + layout.tray.length + " в лотке")
        }

        root.reindex()
        root.layoutChanged()
        root.scheduleSave()
    }

    function seedInstances(metrics: var): var {
        const preferred = ["my.clock", "my.note", "my.color", "my.allowed",
                           "my.palette", "my.switch"]
        const candidates = []
        const used = ({})
        for (const id of preferred) {
            const widget = WidgetRegistry.widgetById(id)
            if (widget && widget.builtin && !used[widget.id]) {
                candidates.push(widget)
                used[widget.id] = true
            }
        }
        for (const widget of WidgetRegistry.widgets) {
            if (widget.builtin && !used[widget.id]) {
                candidates.push(widget)
                used[widget.id] = true
            }
        }

        const placed = []
        for (const widget of candidates) {
            const size = widget.sizeSpec.defaultSize
            const position = root.findFree(placed, size, metrics.rows, metrics.cols)
            if (position)
                placed.push(root.makeInstance(widget, position, size.cols, size.rows))
        }
        return placed
    }

    function findFree(placed: var, size: var, rows: int, cols: int): var {
        if (size.rows > rows || size.cols > cols)
            return null
        for (let row = 0; row <= rows - size.rows; row++) {
            for (let col = 0; col <= cols - size.cols; col++) {
                if (root.isFree(placed, col, row, size.cols, size.rows))
                    return { col: col, row: row }
            }
        }
        return null
    }

    function isFree(placed: var, col: int, row: int, cols: int, rows: int): bool {
        for (const item of placed) {
            if (col < item.col + item.cols && col + cols > item.col
                && row < item.row + item.rows && row + rows > item.row)
                return false
        }
        return true
    }

    function findNearestFree(placed: var, desiredCol: int, desiredRow: int,
                             cols: int, rows: int,
                             gridCols: int, gridRows: int): var {
        if (cols > gridCols || rows > gridRows)
            return null
        let best = null
        let bestDistance = Number.MAX_VALUE
        for (let row = 0; row <= gridRows - rows; row++) {
            for (let col = 0; col <= gridCols - cols; col++) {
                if (!root.isFree(placed, col, row, cols, rows))
                    continue
                const dc = col - desiredCol
                const dr = row - desiredRow
                const distance = dc * dc + dr * dr
                if (distance < bestDistance) {
                    bestDistance = distance
                    best = { col: col, row: row }
                }
            }
        }
        return best
    }

    function migrate(sourceWidgets: var, sourceGrid: var, metrics: var): var {
        const oldCols = sourceGrid && sourceGrid.cols > 0
                      ? sourceGrid.cols : metrics.cols
        const oldRows = sourceGrid && sourceGrid.rows > 0
                      ? sourceGrid.rows : metrics.rows
        const placed = []
        const tray = []

        for (const source of sourceWidgets || []) {
            const widget = WidgetRegistry.widgetById(source.id)
            let cols = Math.max(1, Math.round(source.cols * metrics.cols / oldCols))
            let rows = Math.max(1, Math.round(source.rows * metrics.rows / oldRows))
            if (widget && widget.sizeSpec) {
                const normalized = widget.sizeSpec.normalize(rows, cols)
                rows = normalized.rows
                cols = normalized.cols
            }

            const clone = root.cloneInstance(source)
            clone.cols = cols
            clone.rows = rows
            if (cols > metrics.cols || rows > metrics.rows) {
                clone.col = source.col
                clone.row = source.row
                tray.push(clone)
                continue
            }

            const desiredCol = Math.max(0, Math.min(
                Math.round(source.col * metrics.cols / oldCols), metrics.cols - cols))
            const desiredRow = Math.max(0, Math.min(
                Math.round(source.row * metrics.rows / oldRows), metrics.rows - rows))

            const position = root.findNearestFree(placed, desiredCol, desiredRow,
                                                  cols, rows, metrics.cols, metrics.rows)
            if (position) {
                clone.col = position.col
                clone.row = position.row
                placed.push(clone)
            } else {
                clone.col = source.col
                clone.row = source.row
                tray.push(clone)
            }
        }
        return { widgets: placed, tray: tray }
    }

    // --- Экземпляры ---
    function makeInstance(widget: var, position: var, cols: int, rows: int): var {
        return {
            uid: root.newUid(),
            id: widget.id,
            name: widget.name,
            col: position.col,
            row: position.row,
            cols: cols,
            rows: rows,
            material: null,
            colorMode: null,
            settings: root.defaultSettings(widget)
        }
    }

    function cloneInstance(source: var): var {
        const copy = ({})
        for (const key in source)
            copy[key] = source[key]
        copy.settings = ({})
        if (source.settings) {
            for (const key in source.settings)
                copy.settings[key] = source.settings[key]
        }
        return copy
    }

    function defaultSettings(widget: var): var {
        const values = ({})
        if (!widget || !widget.settingsSchema)
            return values
        for (const setting of widget.settingsSchema)
            values[setting.key] = setting.default
        return values
    }

    function settingsFor(uid: string, widget: var): var {
        const values = root.defaultSettings(widget)
        const instance = root.findInstance(uid)
        if (instance && instance.settings) {
            for (const key in instance.settings)
                values[key] = instance.settings[key]
        }
        return values
    }

    function setMaterial(uid: string, materialId: string): void {
        const instance = root.findInstance(uid)
        if (!instance)
            return
        instance.material = materialId.length > 0 ? materialId : null
        console.info("[widgets/layout] материал " + uid + " = "
                     + (instance.material || "default"))
        root.instanceChanged(uid)
        root.scheduleSave()
    }

    function setColorMode(uid: string, mode: string): void {
        const instance = root.findInstance(uid)
        if (!instance)
            return
        instance.colorMode = (mode === "accent" || mode === "widget") ? mode : null
        console.info("[widgets/layout] режим цвета " + uid + " = "
                     + (instance.colorMode || "default"))
        root.instanceChanged(uid)
        root.scheduleSave()
    }

    function setSetting(uid: string, key: string, value: var): void {
        const instance = root.findInstance(uid)
        if (!instance)
            return
        if (!instance.settings)
            instance.settings = ({})
        instance.settings[key] = value
        console.info("[widgets/layout] настройка " + uid + "." + key + " = "
                     + JSON.stringify(value))
        root.instanceChanged(uid)
        root.scheduleSave()
    }

    function addInstance(screenName: string, widget: var,
                         col: int, row: int, cols: int, rows: int): var {
        const entry = root.screens[screenName]
        if (!entry)
            return null
        let targetCols = cols
        let targetRows = rows
        if (widget.sizeSpec) {
            const normalized = widget.sizeSpec.normalize(rows, cols)
            targetRows = normalized.rows
            targetCols = normalized.cols
        }
        const instance = root.makeInstance(widget, { col: col, row: row },
                                           targetCols, targetRows)
        entry.widgets.push(instance)
        root.reindex()
        root.layoutChanged()
        root.scheduleSave()
        return instance
    }

    function removeInstance(uid: string): void {
        const located = root.locate(uid)
        if (!located)
            return
        const index = located.list.indexOf(located.instance)
        if (index >= 0)
            located.list.splice(index, 1)
        root.reindex()
        console.info("[widgets/layout] удалён экземпляр " + uid)
        root.layoutChanged()
        root.scheduleSave()
    }

    function updateGeometry(uid: string, col: int, row: int,
                            cols: int, rows: int): void {
        const instance = root.findInstance(uid)
        if (!instance)
            return
        instance.col = col
        instance.row = row
        instance.cols = cols
        instance.rows = rows
        root.layoutChanged()
        root.scheduleSave()
    }

    // --- Нормализация загруженного ---
    function normalizeEntry(entry: var): void {
        if (!entry)
            return
        if (!entry.signatures || typeof entry.signatures !== "object")
            entry.signatures = ({})

        let signature = typeof entry.signature === "string" ? entry.signature : ""
        if (signature.length === 0 && entry.grid
            && entry.grid.cols > 0 && entry.grid.rows > 0)
            signature = entry.grid.cols + "x" + entry.grid.rows

        if (!entry.signatures[signature] && entry.widgets) {
            entry.signatures[signature] = {
                grid: entry.grid || { cols: 0, rows: 0 },
                widgets: entry.widgets,
                tray: entry.tray || []
            }
        }
        if (signature.length === 0) {
            const keys = Object.keys(entry.signatures)
            if (keys.length > 0)
                signature = keys[0]
        }

        let current = entry.signatures[signature]
        if (!current) {
            current = {
                grid: entry.grid || { cols: 0, rows: 0 },
                widgets: entry.widgets || [],
                tray: entry.tray || []
            }
            signature = current.grid.cols + "x" + current.grid.rows
            entry.signatures[signature] = current
        }

        for (const key in entry.signatures) {
            const layout = entry.signatures[key]
            layout.grid = layout.grid || { cols: 0, rows: 0 }
            layout.widgets = root.normalizeInstances(layout.widgets)
            layout.tray = root.normalizeInstances(layout.tray)
        }

        entry.signature = signature
        entry.grid = current.grid
        entry.widgets = current.widgets
        entry.tray = current.tray
    }

    function normalizeInstances(list: var): var {
        if (!list || typeof list.length !== "number")
            return []
        const out = []
        for (const item of list) {
            if (!item || typeof item !== "object" || typeof item.id !== "string")
                continue
            const copy = root.cloneInstance(item)
            copy.col = Number.isFinite(copy.col) ? Math.max(0, Math.round(copy.col)) : 0
            copy.row = Number.isFinite(copy.row) ? Math.max(0, Math.round(copy.row)) : 0
            copy.cols = Number.isFinite(copy.cols) ? Math.max(1, Math.round(copy.cols)) : 1
            copy.rows = Number.isFinite(copy.rows) ? Math.max(1, Math.round(copy.rows)) : 1
            copy.name = typeof copy.name === "string" ? copy.name : copy.id
            copy.settings = copy.settings || ({})
            copy.material = typeof copy.material === "string" ? copy.material : null
            copy.colorMode = (copy.colorMode === "accent" || copy.colorMode === "widget")
                            ? copy.colorMode : null
            copy.uid = typeof copy.uid === "string" && copy.uid.length > 0
                     ? copy.uid : root.newUid()
            out.push(copy)
        }
        return out
    }

    function normalizeScreens(loaded: var): var {
        const result = ({})
        if (!loaded || typeof loaded !== "object")
            return result
        const used = ({})
        for (const screenName in loaded) {
            const entry = loaded[screenName]
            if (!entry || typeof entry !== "object")
                continue
            root.normalizeEntry(entry)
            for (const signature in entry.signatures) {
                const layout = entry.signatures[signature]
                for (const listName of ["widgets", "tray"]) {
                    for (const item of layout[listName] || []) {
                        if (used[item.uid]) {
                            item.uid = root.newUid()
                        }
                        used[item.uid] = true
                    }
                }
            }
            result[screenName] = entry
        }
        return result
    }

    function newUid(): string {
        let uid = ""
        do {
            uid = "i" + (root._nextUid++)
        } while (root.uidExists(uid))
        return uid
    }

    function uidExists(uid: string): bool {
        for (const screenName in root.screens) {
            const entry = root.screens[screenName]
            for (const signature in entry.signatures || {}) {
                const layout = entry.signatures[signature]
                for (const listName of ["widgets", "tray"]) {
                    for (const item of layout[listName] || []) {
                        if (item.uid === uid)
                            return true
                    }
                }
            }
        }
        return false
    }

    function reindex(): void {
        let maximum = 0
        for (const screenName in root.screens) {
            const entry = root.screens[screenName]
            for (const signature in entry.signatures || {}) {
                const layout = entry.signatures[signature]
                for (const listName of ["widgets", "tray"]) {
                    for (const item of layout[listName] || []) {
                        const match = /^i(\d+)$/.exec(item.uid || "")
                        if (match)
                            maximum = Math.max(maximum, parseInt(match[1], 10))
                    }
                }
            }
        }
        if (maximum >= root._nextUid)
            root._nextUid = maximum + 1
    }

    // --- Сохранение ---
    function scheduleSave(): void {
        if (!root.ready || root._loading)
            return
        saveTimer.restart()
    }

    function saveState(): void {
        if (!root.ready || root._loading)
            return
        root._lastSaveAt = Date.now()
        state.schema = 1
        state.defaults.material = Config.defaultMaterial
        state.defaults.colorMode = Config.defaultColorMode
        state.screens = JSON.parse(JSON.stringify(root.screens))
        stateFile.writeAdapter()
        console.info("[widgets/layout] сохранено: " + stateFile.path)
    }

    function loadState(): void {
        if (root._loading)
            return
        root._loading = true
        if (state.schema !== 1)
            console.warn("[widgets/layout] schema=" + state.schema + ", ожидается 1")
        const schemaBefore = state.schema
        root.screens = root.normalizeScreens(state.screens || ({}))
        root.ready = true
        root._loading = false
        root.reindex()
        console.info("[widgets/layout] загружено экранов: "
                     + Object.keys(root.screens).length)
        root.layoutChanged()
        if (schemaBefore !== 1)
            root.scheduleSave()
    }

    function stateMissing(): void {
        if (root.ready)
            return
        root.screens = ({})
        root.ready = true
        root.reindex()
        console.info("[widgets/layout] layout.json ещё нет — раскладка будет создана")
        root.layoutChanged()
    }
}
