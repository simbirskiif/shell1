pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QtQml.Models

// Реестр материалов подложки (раздел 6.1 ТЗ).
//
// Материал — папка с meta.json и Material.qml. Пользовательские материалы
// лежат в $XDG_CONFIG_HOME/quickshell/widgets/materials и имеют приоритет над
// встроенными из <shellDir>/materials. Наблюдение за файлами позволяет
// подхватить новый материал и перезагрузить только его экземпляры.
Singleton {
    id: root

    property var materials: []
    property var problems: []
    property bool ready: false
    property int generation: 0

    signal materialChanged(string id)

    readonly property string builtinRoot: (Quickshell.shellDir || "") + "/materials"

    readonly property var searchPaths: {
        const out = []
        const seen = ({})
        const add = function(path) {
            if (!path)
                return
            let value = String(path).trim()
            if (value.length === 0)
                return
            if (value.startsWith("~/"))
                value = (Quickshell.env("HOME") || "") + value.slice(1)
            if (value.length > 1 && value.endsWith("/"))
                value = value.slice(0, -1)
            if (seen[value])
                return
            seen[value] = true
            out.push(value)
        }

        const env = Quickshell.env("QS_MATERIAL_PATH") || ""
        if (env.length > 0) {
            for (const part of env.split(":"))
                add(part)
        }
        add(Config.configBase + "/widgets/materials")
        add(root.builtinRoot)
        return out
    }

    property var _byId: ({})
    property bool _scanning: false
    property bool _rescanQueued: false
    property var _foundMeta: []
    property var _foundMaterial: []
    property var _watcherModel: []
    property var _rootWatcherModel: []
    property var _pendingIds: ({})
    property bool _reloadScheduled: false
    property var _lastSearchPaths: []

    function materialById(id: string): var {
        return root._byId[id] || null
    }

    function urlFor(id: string): string {
        const material = root._byId[id]
        return material ? material.url : ""
    }

    function scheduleScan(): void {
        scanTimer.restart()
    }

    function scan(): void {
        if (root._scanning) {
            root._rescanQueued = true
            return
        }
        const paths = root.searchPaths
        root._scanning = true
        root._foundMeta = []
        root._foundMaterial = []

        if (paths.length === 0) {
            root.finishScan()
            return
        }

        finder.command = ["find"].concat(paths, [
            "-maxdepth", "4",
            "-type", "f",
            "(", "-name", "meta.json", "-o", "-name", "Material.qml", ")",
            "-print"
        ])
        finder.running = true
    }

    function onFoundLine(line: string): void {
        const value = line.trim()
        if (value.endsWith("/meta.json"))
            root._foundMeta.push(value)
        else if (value.endsWith("/Material.qml"))
            root._foundMaterial.push(value)
    }

    function onFindExited(): void {
        if (root._rescanQueued) {
            root._rescanQueued = false
            root._scanning = false
            root.scheduleScan()
            return
        }
        root.finishScan()
    }

    function finishScan(): void {
        const oldById = root._byId
        const oldFingerprints = ({})
        for (const old of root.materials)
            oldFingerprints[old.id] = old.fingerprint

        const entries = []
        for (const metaPath of root._foundMeta) {
            const dir = root.dirname(metaPath)
            const rootPath = root.rootFor(metaPath)
            if (!rootPath)
                continue
            const depth = root.relativeDepth(dir, rootPath)
            // Как и у виджетов: путь может указывать на папку с материалами
            // или непосредственно на папку материала.
            if (depth < 0 || depth > 2)
                continue
            entries.push({
                dir: dir,
                metaPath: metaPath,
                priority: root.pathPriority(metaPath),
                rootPath: rootPath
            })
        }
        entries.sort(function(a, b) {
            if (a.priority !== b.priority)
                return a.priority - b.priority
            return a.metaPath < b.metaPath ? -1 : (a.metaPath > b.metaPath ? 1 : 0)
        })

        const parsed = []
        const problems = []
        const byId = ({})
        const seenDirs = ({})

        for (const entry of entries) {
            if (seenDirs[entry.dir])
                continue
            seenDirs[entry.dir] = true

            const materialPath = entry.dir + "/Material.qml"
            if (root._foundMaterial.indexOf(materialPath) < 0) {
                problems.push({
                    dir: entry.dir,
                    error: "нет Material.qml",
                    metaPath: entry.metaPath
                })
                continue
            }

            const metaReader = metaReaderComponent.createObject(root, {
                targetPath: entry.metaPath
            })
            let text = ""
            if (metaReader) {
                try {
                    metaReader.waitForJob()
                    text = metaReader.text()
                } catch (e) {
                    text = ""
                }
                metaReader.destroy()
            }
            if (!text || text.length === 0) {
                problems.push({
                    dir: entry.dir,
                    error: "пустой или недоступный meta.json",
                    metaPath: entry.metaPath
                })
                continue
            }

            let meta = null
            try {
                meta = JSON.parse(text)
            } catch (e) {
                problems.push({
                    dir: entry.dir,
                    error: "meta.json не разбирается: " + e.message,
                    metaPath: entry.metaPath
                })
                continue
            }

            let id = typeof meta.id === "string" ? meta.id.trim() : ""
            if (id.length === 0)
                id = root.basename(entry.dir)
            if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)) {
                problems.push({
                    dir: entry.dir,
                    error: "недопустимый id материала: " + id,
                    metaPath: entry.metaPath
                })
                continue
            }
            if (byId[id]) {
                console.warn("[widgets/materials] конфликт id " + id + ": "
                             + byId[id].dir + " побеждает " + entry.dir)
                continue
            }

            const material = {
                id: id,
                name: typeof meta.name === "string" && meta.name.length > 0
                      ? meta.name : id,
                description: typeof meta.description === "string"
                             ? meta.description : "",
                dir: entry.dir,
                metaPath: entry.metaPath,
                materialPath: materialPath,
                url: root.pathToUrl(materialPath),
                builtin: root.isUnder(root.builtinRoot, entry.dir),
                fingerprint: entry.metaPath + "|" + text
            }
            byId[id] = material
            parsed.push(material)
        }

        parsed.sort(function(a, b) {
            return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
        })

        // Сначала byId: обработчик materialsChanged у host должен видеть
        // новый набор материалов.
        root._byId = byId
        root.materials = parsed
        root.problems = problems
        root.ready = true
        root.generation++
        root._scanning = false
        root.updateWatchers()

        for (const problem of problems)
            console.warn("[widgets/materials] проблема " + problem.dir + ": " + problem.error)

        for (const material of parsed) {
            if (oldById[material.id]
                && oldFingerprints[material.id] !== material.fingerprint) {
                console.info("[widgets/materials] meta изменилась: " + material.id)
                root.materialChanged(material.id)
            }
        }

        console.info("[widgets/materials] доступно " + parsed.length + ": "
                     + parsed.map(function(m) { return m.id }).join(", "))

        if (root._rescanQueued) {
            root._rescanQueued = false
            root.scheduleScan()
        }
    }

    function updateWatchers(): void {
        const model = []
        const seen = ({})
        const add = function(path, id, kind) {
            const key = kind + "|" + path
            if (seen[key])
                return
            seen[key] = true
            model.push({ path: path, id: id, kind: kind })
        }

        for (const material of root.materials) {
            add(material.metaPath, material.id, "meta")
            add(material.dir, material.id, "dir")
            add(material.materialPath, material.id, "material")
        }

        root._watcherModel = model
        root._rootWatcherModel = root.searchPaths.slice()
    }

    function onWatchedFile(path: string, id: string, kind: string): void {
        if (kind === "meta" || kind === "dir") {
            root.scheduleScan()
            return
        }
        root.queueReload(id)
    }

    function queueReload(id: string): void {
        if (!id)
            return
        root._pendingIds[id] = true
        if (!root._reloadScheduled) {
            root._reloadScheduled = true
            reloadTimer.restart()
        }
    }

    function flushReloads(): void {
        const ids = Object.keys(root._pendingIds)
        root._pendingIds = ({})
        root._reloadScheduled = false
        for (const id of ids) {
            console.info("[widgets/materials] QML изменился: " + id)
            root.materialChanged(id)
        }
    }

    function rootFor(path: string): string {
        for (const candidate of root.searchPaths) {
            if (path === candidate || path.startsWith(candidate + "/"))
                return candidate
        }
        return ""
    }

    function pathPriority(path: string): int {
        const roots = root.searchPaths
        for (let i = 0; i < roots.length; i++) {
            if (path === roots[i] || path.startsWith(roots[i] + "/"))
                return i
        }
        return roots.length
    }

    function relativeDepth(dir: string, searchRoot: string): int {
        if (!searchRoot || !dir.startsWith(searchRoot))
            return 99
        const relative = dir.slice(searchRoot.length).replace(/^\/+/, "")
        if (relative.length === 0)
            return 0
        return relative.split("/").length
    }

    function isUnder(dir: string, file: string): bool {
        return file === dir || file.startsWith(dir + "/")
    }

    function dirname(path: string): string {
        const index = path.lastIndexOf("/")
        return index > 0 ? path.slice(0, index) : "/"
    }

    function basename(path: string): string {
        const index = path.lastIndexOf("/")
        return index >= 0 ? path.slice(index + 1) : path
    }

    function pathToUrl(path: string): string {
        return "file://" + path.split("/").map(function(part) {
            return encodeURIComponent(part)
        }).join("/")
    }

    Process {
        id: finder

        stdout: SplitParser {
            onRead: line => root.onFoundLine(line)
        }

        onExited: (exitCode, exitStatus) => root.onFindExited()
    }

    Timer {
        id: scanTimer
        interval: 250
        repeat: false
        onTriggered: root.scan()
    }

    Timer {
        id: reloadTimer
        interval: 120
        repeat: false
        onTriggered: root.flushReloads()
    }

    Component {
        id: metaReaderComponent

        FileView {
            id: metaReader

            property string targetPath: ""

            path: metaReader.targetPath
            preload: true
            watchChanges: false
            printErrors: false
        }
    }

    Instantiator {
        model: root._watcherModel

        delegate: FileView {
            required property var modelData

            path: modelData.path
            watchChanges: true
            preload: false
            printErrors: false

            onFileChanged: root.onWatchedFile(modelData.path, modelData.id, modelData.kind)
        }
    }

    Instantiator {
        model: root._rootWatcherModel

        delegate: FileView {
            required property var modelData

            path: modelData
            watchChanges: true
            preload: false
            printErrors: false

            onFileChanged: root.scheduleScan()
        }
    }

    function samePaths(a: var, b: var): bool {
        if (a.length !== b.length)
            return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    onSearchPathsChanged: {
        const current = root.searchPaths
        if (root.samePaths(current, root._lastSearchPaths))
            return
        root._lastSearchPaths = current.slice()
        root.scheduleScan()
    }

    Component.onCompleted: {
        root._lastSearchPaths = root.searchPaths.slice()
        root.scheduleScan()
    }
}
