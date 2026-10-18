import QtQuick
import Quickshell
import Quickshell.Io

// Внешнее управление через IPC: qs ipc call widgets <функция>.
// На этапе 3 здесь переключение материала/режима цвета для проверки и
// будущий попап настроек; на этапе 5 сюда добавится edit toggle.
IpcHandler {
    target: "widgets"

    function state(): string {
        const lines = []
        for (const screenName in LayoutStore.screens) {
            const entry = LayoutStore.screens[screenName]
            lines.push("screen " + screenName + ": " + (entry.signature || "?")
                       + " " + (entry.grid ? entry.grid.cols + "x" + entry.grid.rows : "?")
                       + ", tray=" + (entry.tray ? entry.tray.length : 0)
                       + ", signatures=" + Object.keys(entry.signatures || {}).join(","))
            for (const instance of entry.widgets || []) {
                lines.push(instance.uid + " " + instance.id + " @" + screenName
                           + " " + instance.col + "," + instance.row
                           + " " + instance.cols + "x" + instance.rows
                           + " material=" + (instance.material || "default")
                           + " mode=" + (instance.colorMode || "default"))
            }
        }
        lines.push("materials: " + MaterialRegistry.materials.map(function(m) {
            return m.id
        }).join(","))
        lines.push("wallpaper: " + Wallpaper.sourceUrl)
        lines.push("extraPaths: " + (Config.extraPaths || []).join(":"))
        lines.push("editing: " + (EditorState.active ? "true" : "false")
                   + " undo=" + EditorState.undoStack.length
                   + " redo=" + EditorState.redoStack.length)
        return lines.join("\n")
    }

    function edit(action: string): string {
        if (action === "toggle")
            EditorState.toggle()
        else if (action === "on")
            EditorState.enter()
        else if (action === "off")
            EditorState.exitCommit()
        else if (action === "cancel")
            EditorState.cancel()
        else if (action === "undo")
            EditorState.undo()
        else if (action === "redo")
            EditorState.redo()
        return state()
    }

    function addPath(path: string): string {
        if (Config.addExtraPath(path))
            WidgetRegistry.scheduleScan()
        return state()
    }

    function picker(): string {
        if (EditorState.pickerOpen)
            EditorState.closePicker()
        else
            EditorState.openPicker(Quickshell.screens.length > 0
                                   ? Quickshell.screens[0].name : "")
        return state()
    }

    function settings(uid: string): string {
        const located = LayoutStore.locate(uid)
        if (located)
            EditorState.openSettings(uid, located.screen)
        return state()
    }

    function material(uid: string, materialId: string): string {
        LayoutStore.setMaterial(uid, materialId)
        return state()
    }

    function colorMode(uid: string, mode: string): string {
        LayoutStore.setColorMode(uid, mode)
        return state()
    }

    function materialList(): string {
        return MaterialRegistry.materials.map(function(m) {
            return m.id + " — " + m.name
        }).join("\n")
    }

    function rescan(): string {
        WidgetRegistry.scheduleScan()
        MaterialRegistry.scheduleScan()
        return state()
    }
}
