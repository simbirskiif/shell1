pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import "../core"

// Единая логика drag/resize/snap/валидации (раздел 8.3–8.4 ТЗ).
//
// Экранные координаты — в логических пикселях окна слоя. Во время жеста
// LayoutStore не меняется: двигается только preview, поэтому карточка и
// MouseArea не прыгают под курсором. На отпускании валидный preview
// применяется через LayoutStore.updateGeometry() и сохраняется.
Singleton {
    id: root

    property bool active: false
    property string uid: ""
    property string screenName: ""
    property string mode: "drag"
    property string edge: ""
    property var metrics: null

    property real startX: 0
    property real startY: 0
    property real dx: 0
    property real dy: 0
    property int originCol: 0
    property int originRow: 0
    property int originCols: 1
    property int originRows: 1

    property int col: 0
    property int row: 0
    property int cols: 1
    property int rows: 1
    property bool valid: false
    property bool moved: false

    function startDrag(host: var, point: var): void {
        root.begin(host, "drag", "", point)
    }

    function startResize(host: var, edge: string, point: var): void {
        if (!host.widget || !host.widget.sizeSpec || !host.widget.sizeSpec.scalable)
            return
        root.begin(host, "resize", edge, point)
    }

    function begin(host: var, mode: string, edge: string, point: var): void {
        if (!host.instance)
            return
        const instance = LayoutStore.findInstance(host.instance.uid)
        if (!instance || !host.metrics)
            return

        root.uid = instance.uid
        root.screenName = host.screen ? host.screen.name : ""
        root.metrics = host.metrics
        root.mode = mode
        root.edge = edge
        root.startX = point.x
        root.startY = point.y
        root.dx = 0
        root.dy = 0
        root.originCol = instance.col
        root.originRow = instance.row
        root.originCols = instance.cols
        root.originRows = instance.rows
        root.col = instance.col
        root.row = instance.row
        root.cols = instance.cols
        root.rows = instance.rows
        root.valid = true
        root.moved = false
        root.active = true
        EditorState.beginOperation()
    }

    function update(point: var): void {
        if (!root.active || !root.metrics)
            return
        const step = root.metrics.cell + root.metrics.gap
        if (step <= 0)
            return
        const dx = point.x - root.startX
        const dy = point.y - root.startY
        root.dx = dx
        root.dy = dy

        if (root.mode === "drag") {
            const maxCol = root.metrics.cols - root.originCols
            const maxRow = root.metrics.rows - root.originRows
            if (maxCol < 0 || maxRow < 0) {
                root.valid = false
                return
            }
            root.cols = root.originCols
            root.rows = root.originRows
            root.col = Math.max(0, Math.min(maxCol,
                root.originCol + Math.round(dx / step)))
            root.row = Math.max(0, Math.min(maxRow,
                root.originRow + Math.round(dy / step)))
            root.valid = root.canPlace(root.uid, root.screenName,
                                       root.col, root.row, root.cols, root.rows)
            root.moved = root.col !== root.originCol || root.row !== root.originRow
        } else {
            root.updateResize(dx, dy, step)
        }
    }

    function updateResize(dx: real, dy: real, step: real): void {
        const left = root.edge.indexOf("left") >= 0
        const right = root.edge.indexOf("right") >= 0
        const top = root.edge.indexOf("top") >= 0
        const bottom = root.edge.indexOf("bottom") >= 0
        const dc = Math.round(dx / step)
        const dr = Math.round(dy / step)

        const rawCols = Math.max(1, root.originCols + (right ? dc : 0) - (left ? dc : 0))
        const rawRows = Math.max(1, root.originRows + (bottom ? dr : 0) - (top ? dr : 0))

        const instance = LayoutStore.findInstance(root.uid)
        const widget = instance ? WidgetRegistry.widgetById(instance.id) : null
        const spec = widget ? widget.sizeSpec : null

        let candidates = []
        if (spec && spec.kind === "list") {
            candidates = spec.allowed.map(function(candidate) {
                const ddc = candidate.cols - rawCols
                const ddr = candidate.rows - rawRows
                return {
                    cols: candidate.cols,
                    rows: candidate.rows,
                    distance: ddc * ddc + ddr * ddr
                }
            }).sort(function(a, b) {
                return a.distance - b.distance
            })
        } else if (spec) {
            const normalized = spec.normalize(rawRows, rawCols)
            candidates = [{ cols: normalized.cols, rows: normalized.rows,
                            distance: 0 }]
        } else {
            candidates = [{ cols: rawCols, rows: rawRows, distance: 0 }]
        }

        let chosen = null
        let fallback = null
        for (const candidate of candidates) {
            if (candidate.cols > root.metrics.cols || candidate.rows > root.metrics.rows) {
                if (!fallback)
                    fallback = candidate
                continue
            }
            const candidateCol = root.originCol + (left ? root.originCols - candidate.cols : 0)
            const candidateRow = root.originRow + (top ? root.originRows - candidate.rows : 0)
            if (candidateCol < 0 || candidateRow < 0) {
                if (!fallback)
                    fallback = candidate
                continue
            }
            if (!fallback)
                fallback = candidate
            if (root.canPlace(root.uid, root.screenName, candidateCol, candidateRow,
                              candidate.cols, candidate.rows)) {
                chosen = { candidate: candidate, col: candidateCol, row: candidateRow }
                break
            }
        }

        if (!chosen && fallback) {
            const candidateCol = Math.max(0, root.originCol
                + (left ? root.originCols - fallback.cols : 0))
            const candidateRow = Math.max(0, root.originRow
                + (top ? root.originRows - fallback.rows : 0))
            chosen = { candidate: fallback, col: candidateCol, row: candidateRow }
            root.valid = false
        } else if (chosen) {
            root.valid = true
        } else {
            root.valid = false
            return
        }

        root.cols = chosen.candidate.cols
        root.rows = chosen.candidate.rows
        root.col = chosen.col
        root.row = chosen.row
        root.moved = root.col !== root.originCol || root.row !== root.originRow
                  || root.cols !== root.originCols || root.rows !== root.originRows
    }

    function canPlace(uid: string, screenName: string,
                      col: int, row: int, cols: int, rows: int): bool {
        if (!root.metrics)
            return false
        if (col < 0 || row < 0 || cols < 1 || rows < 1)
            return false
        if (col + cols > root.metrics.cols || row + rows > root.metrics.rows)
            return false
        const instances = LayoutStore.instancesFor(screenName)
        for (const instance of instances) {
            if (instance.uid === uid)
                continue
            if (col < instance.col + instance.cols && col + cols > instance.col
                && row < instance.row + instance.rows && row + rows > instance.row)
                return false
        }
        return true
    }

    function finish(): void {
        if (!root.active)
            return
        const apply = root.valid && root.moved
        const uid = root.uid
        const col = root.col
        const row = root.row
        const cols = root.cols
        const rows = root.rows
        root.reset()
        if (apply) {
            LayoutStore.applyGeometry(uid, col, row, cols, rows)
            console.info("[widgets/editor] " + uid + " -> " + col + "," + row
                         + " " + cols + "x" + rows)
        }
    }

    function cancel(): void {
        root.reset()
    }

    function reset(): void {
        root.active = false
        root.uid = ""
        root.screenName = ""
        root.mode = "drag"
        root.edge = ""
        root.metrics = null
        root.valid = false
        root.moved = false
        root.dx = 0
        root.dy = 0
    }
}
