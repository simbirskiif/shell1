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
            for (const instance of LayoutStore.screens[screenName]) {
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
        return lines.join("\n")
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
