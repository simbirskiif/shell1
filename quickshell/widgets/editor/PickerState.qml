pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import "../core"

// Состояние drag-and-drop из каталога на сетку (раздел 8.5 ТЗ).
// Геометрия ghost считается в координатах окна слоя, как и DragController.
Singleton {
    id: root

    property bool active: false
    property var widget: null
    property string screenName: ""
    property var metrics: null
    property int col: 0
    property int row: 0
    property int cols: 1
    property int rows: 1
    property bool valid: false
    property string message: ""

    function start(widget: var, metrics: var, screenName: string, point: var): void {
        if (!widget || !metrics)
            return
        root.widget = widget
        root.metrics = metrics
        root.screenName = screenName
        root.cols = widget.sizeSpec ? widget.sizeSpec.defaultSize.cols : 1
        root.rows = widget.sizeSpec ? widget.sizeSpec.defaultSize.rows : 1
        root.active = true
        root.message = ""
        root.update(point)
    }

    function update(point: var): void {
        if (!root.active || !root.metrics)
            return
        const step = root.metrics.cell + root.metrics.gap
        if (step <= 0)
            return
        root.col = Math.max(0, Math.min(root.metrics.cols - root.cols,
            Math.round((point.x - root.metrics.originX) / step)))
        root.row = Math.max(0, Math.min(root.metrics.rows - root.rows,
            Math.round((point.y - root.metrics.originY) / step)))
        root.valid = root.canPlace()
    }

    function canPlace(): bool {
        if (!root.metrics)
            return false
        if (root.cols > root.metrics.cols || root.rows > root.metrics.rows)
            return false
        const instances = LayoutStore.instancesFor(root.screenName)
        for (const instance of instances) {
            if (root.col < instance.col + instance.cols
                && root.col + root.cols > instance.col
                && root.row < instance.row + instance.rows
                && root.row + root.rows > instance.row)
                return false
        }
        return true
    }

    function finish(): bool {
        if (!root.active) {
            return false
        }
        const added = root.valid && root.widget
            ? LayoutStore.addInstance(root.screenName, root.widget,
                                      root.col, root.row, root.cols, root.rows)
            : null
        if (!added)
            root.message = root.valid ? "Нет места" : "Здесь нельзя разместить виджет"
        root.reset()
        return added !== null
    }

    function cancel(): void {
        root.reset()
    }

    function reset(): void {
        root.active = false
        root.widget = null
        root.metrics = null
        root.screenName = ""
        root.valid = false
    }
}
