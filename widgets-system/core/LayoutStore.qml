pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell

// Раскладка экземпляров виджетов (раздел 7 ТЗ).
//
// Этап 2: состояние живёт в памяти, при первом появлении экрана в него
// раскладываются встроенные виджеты. Этап 4 добавит файл
// ~/.local/state/quickshell/widgets/layout.json, миграцию при смене сетки,
// лоток и восстановление после перезапуска. Публичный API уже рассчитан на
// это: экземпляры адресуются по uid, настройки — по uid и ключу.
Singleton {
    id: root

    // screenName -> массив экземпляров.
    property var screens: ({})
    // uid -> экземпляр для быстрого поиска.
    property var _byUid: ({})
    property int _nextUid: 1

    // Изменился набор/геометрия экземпляров.
    signal layoutChanged()
    // Изменились настройки конкретного экземпляра.
    signal instanceChanged(string uid)

    function instancesFor(screenName: string): var {
        const list = root.screens[screenName]
        return list ? list.slice() : []
    }

    function ensureScreen(screenName: string, metrics: var): void {
        if (!WidgetRegistry.ready)
            return
        if (root.screens[screenName] !== undefined)
            return

        const instances = root.seedInstances(screenName, metrics)
        root.screens[screenName] = instances
        root.reindex()
        console.info("[widgets/layout] раскладка " + screenName + ": "
                     + instances.length + " экземпляров")
        root.layoutChanged()
    }

    function seedInstances(screenName: string, metrics: var): var {
        const preferred = ["my.clock", "my.note", "my.color", "my.allowed", "my.palette", "my.switch"]
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
            if (!position) {
                console.warn("[widgets/layout] для " + widget.id
                             + " нет места на " + screenName)
                continue
            }
            console.info("[widgets/layout] " + widget.id + " -> "
                         + position.col + "," + position.row + " "
                         + size.cols + "x" + size.rows)
            placed.push(root.makeInstance(screenName, widget, position,
                                          size.cols, size.rows))
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

    function makeInstance(screenName: string, widget: var, position: var,
                          cols: int, rows: int): var {
        return {
            uid: "i" + (root._nextUid++),
            id: widget.id,
            name: widget.name,
            screen: screenName,
            col: position.col,
            row: position.row,
            cols: cols,
            rows: rows,
            material: null,
            colorMode: null,
            settings: root.defaultSettings(widget)
        }
    }

    function defaultSettings(widget: var): var {
        const values = ({})
        if (!widget || !widget.settingsSchema)
            return values
        for (const setting of widget.settingsSchema)
            values[setting.key] = setting.default
        return values
    }

    function findInstance(uid: string): var {
        for (const screenName in root.screens) {
            const list = root.screens[screenName]
            for (let i = 0; i < list.length; i++) {
                if (list[i].uid === uid)
                    return list[i]
            }
        }
        return null
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
        console.info("[widgets/layout] материал " + uid + " = " + (instance.material || "default"))
        root.instanceChanged(uid)
    }

    function setColorMode(uid: string, mode: string): void {
        const instance = root.findInstance(uid)
        if (!instance)
            return
        instance.colorMode = (mode === "accent" || mode === "widget") ? mode : null
        console.info("[widgets/layout] режим цвета " + uid + " = " + (instance.colorMode || "default"))
        root.instanceChanged(uid)
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
    }

    function addInstance(screenName: string, widget: var,
                         col: int, row: int, cols: int, rows: int): var {
        if (!root.screens[screenName])
            root.screens[screenName] = []
        const instance = root.makeInstance(screenName, widget,
                                           { col: col, row: row }, cols, rows)
        root.screens[screenName].push(instance)
        root.reindex()
        root.layoutChanged()
        return instance
    }

    function removeInstance(uid: string): void {
        const instance = root.findInstance(uid)
        if (!instance)
            return
        const list = root.screens[instance.screen]
        if (!list)
            return
        const index = list.indexOf(instance)
        if (index >= 0)
            list.splice(index, 1)
        delete root._byUid[uid]
        console.info("[widgets/layout] удалён экземпляр " + uid)
        root.layoutChanged()
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
    }

    function reindex(): void {
        const map = ({})
        for (const screenName in root.screens) {
            for (const instance of root.screens[screenName])
                map[instance.uid] = instance
        }
        root._byUid = map
    }
}
