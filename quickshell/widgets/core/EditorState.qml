pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell

// Состояние режима редактирования и стек undo/redo (раздел 8 ТЗ).
//
// Снимок — это глубокая копия всей раскладки. Операции drag/resize/удаление
// вызывают beginOperation() один раз перед началом, поэтому undo возвращает
// состояние до жеста, а не каждый промежуточный шаг.
Singleton {
    id: root

    property bool active: false
    property var initialSnapshot: null
    property var undoStack: []
    property var redoStack: []
    property bool pickerOpen: false
    property string uiScreen: ""
    property string settingsUid: ""
    property string settingsScreen: ""
    property string selectedUid: ""
    property bool globalOpen: false

    readonly property bool hasUndo: undoStack.length > 0
    readonly property bool hasRedo: redoStack.length > 0

    function enter(): void {
        if (root.active || !LayoutStore.ready)
            return
        root.initialSnapshot = LayoutStore.snapshot()
        root.undoStack = []
        root.redoStack = []
        root.pickerOpen = false
        root.settingsUid = ""
        root.settingsScreen = ""
        root.selectedUid = ""
        root.globalOpen = false
        root.active = true
        console.info("[widgets/editor] режим редактирования включён")
    }

    function exitCommit(): void {
        if (!root.active)
            return
        root.active = false
        root.pickerOpen = false
        root.settingsUid = ""
        root.settingsScreen = ""
        root.selectedUid = ""
        root.globalOpen = false
        root.initialSnapshot = null
        root.undoStack = []
        root.redoStack = []
        LayoutStore.scheduleSave()
        console.info("[widgets/editor] режим редактирования выключен")
    }

    function cancel(): void {
        if (!root.active)
            return
        if (root.initialSnapshot)
            LayoutStore.restoreSnapshot(root.initialSnapshot)
        root.active = false
        root.pickerOpen = false
        root.settingsUid = ""
        root.settingsScreen = ""
        root.selectedUid = ""
        root.globalOpen = false
        root.initialSnapshot = null
        root.undoStack = []
        root.redoStack = []
        console.info("[widgets/editor] изменения отменены")
    }

    function toggle(): void {
        if (root.active)
            root.exitCommit()
        else
            root.enter()
    }

    function openPicker(screenName: string): void {
        if (!root.active)
            root.enter()
        if (!root.active)
            return
        root.pickerOpen = true
        root.uiScreen = screenName
        root.settingsUid = ""
        root.settingsScreen = ""
        root.globalOpen = false
    }

    function closePicker(): void {
        root.pickerOpen = false
    }

    function openSettings(uid: string, screenName: string): void {
        if (!root.active)
            root.enter()
        if (!root.active)
            return
        root.settingsUid = uid
        root.settingsScreen = screenName
        root.pickerOpen = false
        root.globalOpen = false
    }

    function closeSettings(): void {
        root.settingsUid = ""
        root.settingsScreen = ""
    }

    // Глобальные параметры виджетов (материал/цвет по умолчанию) живут в том
    // же окне слоя, без отдельного окна-настройщика.
    function openGlobalSettings(screenName: string): void {
        if (!root.active)
            root.enter()
        if (!root.active)
            return
        root.settingsUid = ""
        root.settingsScreen = ""
        root.pickerOpen = false
        root.globalOpen = true
        root.uiScreen = screenName
    }

    function closeGlobalSettings(): void {
        root.globalOpen = false
    }

    function select(uid: string): void {
        root.selectedUid = uid
    }

    function clearSelection(): void {
        root.selectedUid = ""
        root.globalOpen = false
    }

    function beginOperation(): void {
        if (!root.active)
            return
        root.undoStack.push(LayoutStore.snapshot())
        if (root.undoStack.length > 50)
            root.undoStack.shift()
        root.redoStack = []
    }

    function undo(): void {
        if (root.undoStack.length === 0)
            return
        root.redoStack.push(LayoutStore.snapshot())
        const snapshot = root.undoStack.pop()
        LayoutStore.restoreSnapshot(snapshot)
        console.info("[widgets/editor] undo")
    }

    function redo(): void {
        if (root.redoStack.length === 0)
            return
        root.undoStack.push(LayoutStore.snapshot())
        const snapshot = root.redoStack.pop()
        LayoutStore.restoreSnapshot(snapshot)
        console.info("[widgets/editor] redo")
    }
}
