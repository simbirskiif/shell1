pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QtQml.Models

// Реестр виджетов (раздел 4 ТЗ): поиск папок с manifest.json, валидация,
// список доступных виджетов и наблюдение за изменениями.
//
// Поиск идёт по путям в порядке приоритета: extraPaths из конфига,
// $QS_WIDGET_PATH, ~/.config/quickshell/widgets, builtin-widgets рядом с
// shell.qml, /usr/share/quickshell-widgets. Сканирование — find на глубину
// до двух вложенных папок с манифестом; символические ссылки не разворачиваются,
// поэтому циклов нет.
Singleton {
    id: root

    // --- Публичное состояние ---
    // Массив описаний валидных виджетов. Каждый элемент:
    // { id, name, description, version, author, icon, dir, manifestPath,
    //   entryPath, entryUrl, sizeSpec, settingsSchema, materials, colorModes,
    //   palette, builtin, files, fingerprint, manifest }
    property var widgets: []
    // Невалидные манифесты: { dir, name, manifestPath, error }.
    property var problems: []
    // Конфликты id: { id, name, winner, loser }.
    property var conflicts: []
    // true после первого завершённого сканирования.
    property bool ready: false
    property int generation: 0

    signal registryChanged()
    // Изменился QML/манифест конкретного виджета — его экземпляры нужно
    // перезагрузить, остальные не трогаем.
    signal widgetChanged(string id)

    // --- Внутреннее состояние ---
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string builtinRoot: (Quickshell.shellDir || "") + "/builtin-widgets"

    readonly property var searchPaths: {
        const out = []
        const seen = ({})
        const add = function(path) {
            if (!path)
                return
            const value = root.expandPath(path)
            if (!value || seen[value])
                return
            seen[value] = true
            out.push(value)
        }

        const extra = Config.extraPaths || []
        for (let i = 0; i < extra.length; i++)
            add(extra[i])

        const env = Quickshell.env("QS_WIDGET_PATH") || ""
        if (env.length > 0) {
            for (const part of env.split(":"))
                add(part)
        }

        add(Config.configBase + "/widgets")
        add(root.builtinRoot)
        add("/usr/share/quickshell-widgets")
        return out
    }

    property bool _scanning: false
    property bool _rescanQueued: false
    property var _foundManifests: []
    property var _foundQml: []
    property var _rawManifests: ({})
    property var _byId: ({})
    property var _watcherModel: []
    property var _rootWatcherModel: []
    property var _pendingReloadIds: ({})
    property bool _reloadScheduled: false

    function widgetById(id: string): var {
        return root._byId[id] || null
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
        root._foundManifests = []
        root._foundQml = []
        root._rawManifests = ({})

        if (paths.length === 0) {
            root.finishScan()
            return
        }

        finder.command = ["find"].concat(paths, [
            "-maxdepth", "6",
            "-type", "f",
            "(", "-name", "manifest.json", "-o", "-name", "*.qml", ")",
            "-print"
        ])
        finder.running = true
    }

    function onFoundLine(line: string): void {
        const value = line.trim()
        if (value.length === 0)
            return
        if (value.endsWith("/manifest.json"))
            root._foundManifests.push(value)
        else if (value.endsWith(".qml"))
            root._foundQml.push(value)
    }

    function onFindExited(): void {
        if (root._rescanQueued) {
            root._rescanQueued = false
            root._scanning = false
            root.scheduleScan()
            return
        }
        root.beginManifestReads()
    }

    function beginManifestReads(): void {
        const unique = []
        const seen = ({})
        for (const path of root._foundManifests) {
            if (seen[path])
                continue
            seen[path] = true
            unique.push(path)
        }

        const entries = []
        for (const manifestPath of unique) {
            const dir = root.dirname(manifestPath)
            const priority = root.pathPriority(manifestPath)
            const scanRoot = root.rootFor(manifestPath)
            const depth = root.relativeDepth(dir, scanRoot)
            // Папка с манифестом должна лежать на глубине 1-2 от корня поиска.
            if (depth < 1 || depth > 2)
                continue
            entries.push({ path: manifestPath, dir: dir, priority: priority, root: scanRoot })
        }

        entries.sort(function(a, b) {
            if (a.priority !== b.priority)
                return a.priority - b.priority
            return a.path < b.path ? -1 : (a.path > b.path ? 1 : 0)
        })

        // Манифесты маленькие: читаем синхронно, чтобы не плодить состояния
        // «сколько читателей ещё не ответило». preload: true + text().
        for (const entry of entries) {
            const reader = manifestReaderComponent.createObject(root, {
                manifestPath: entry.path
            })
            if (!reader) {
                root.onManifestFailed(entry.dir, entry.priority, entry.path,
                                      entry.root, "не удалось создать читатель")
                continue
            }
            let text = ""
            try {
                reader.waitForJob()
                text = reader.text()
            } catch (e) {
                text = ""
            }
            reader.destroy()
            if (text && text.length > 0)
                root.onManifestLoaded(entry.dir, entry.priority, entry.path, entry.root, text)
            else
                root.onManifestFailed(entry.dir, entry.priority, entry.path,
                                      entry.root, "пустой или недоступный manifest.json")
        }

        root.finishScan()
    }

    function onManifestLoaded(widgetDir: string, priority: int, manifestPath: string,
                              scanRoot: string, text: string): void {
        root._rawManifests[manifestPath] = {
            dir: widgetDir,
            priority: priority,
            path: manifestPath,
            root: scanRoot,
            text: text,
            error: ""
        }
    }

    function onManifestFailed(widgetDir: string, priority: int, manifestPath: string,
                              scanRoot: string, error: string): void {
        root._rawManifests[manifestPath] = {
            dir: widgetDir,
            priority: priority,
            path: manifestPath,
            root: scanRoot,
            text: "",
            error: error || "не удалось прочитать manifest.json"
        }
    }

    function finishScan(): void {
        const rawList = []
        for (const key in root._rawManifests)
            rawList.push(root._rawManifests[key])

        rawList.sort(function(a, b) {
            if (a.priority !== b.priority)
                return a.priority - b.priority
            return a.path < b.path ? -1 : (a.path > b.path ? 1 : 0)
        })

        const oldById = root._byId
        const oldFingerprints = ({})
        for (const old of root.widgets)
            oldFingerprints[old.id] = old.fingerprint

        const parsed = []
        const problems = []
        const conflicts = []
        const byId = ({})

        for (const raw of rawList) {
            const dirName = root.basename(raw.dir)
            if (raw.error.length > 0) {
                problems.push({
                    dir: raw.dir,
                    name: dirName,
                    manifestPath: raw.path,
                    error: raw.error
                })
                continue
            }

            let manifest = null
            try {
                manifest = JSON.parse(raw.text)
            } catch (e) {
                problems.push({
                    dir: raw.dir,
                    name: dirName,
                    manifestPath: raw.path,
                    error: "JSON не разбирается: " + e.message
                })
                continue
            }

            const files = [raw.path]
            for (const file of root._foundQml) {
                if (root.isUnder(raw.dir, file))
                    files.push(file)
            }
            files.sort()

            const result = root.validateManifest(manifest, raw, files)
            if (!result.ok) {
                problems.push({
                    dir: raw.dir,
                    name: manifest && typeof manifest.name === "string"
                          ? manifest.name : dirName,
                    manifestPath: raw.path,
                    error: result.errors.join("; ")
                })
                continue
            }

            if (byId[result.widget.id]) {
                conflicts.push({
                    id: result.widget.id,
                    name: result.widget.name,
                    winner: byId[result.widget.id].dir,
                    loser: raw.dir
                })
                console.warn("[widgets/registry] конфликт id " + result.widget.id
                             + ": " + byId[result.widget.id].dir + " побеждает " + raw.dir)
                continue
            }

            result.widget.files = files
            result.widget.fingerprint = raw.path + "|" + raw.text + "|" + files.join("|")
            byId[result.widget.id] = result.widget
            parsed.push(result.widget)
        }

        parsed.sort(function(a, b) {
            return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
        })

        root.widgets = parsed
        root.problems = problems
        root.conflicts = conflicts
        root._byId = byId
        root.ready = true
        root.generation++
        root._scanning = false
        root.updateWatchers()

        for (const problem of problems)
            console.warn("[widgets/registry] проблемный виджет " + problem.dir + ": " + problem.error)

        console.info("[widgets/registry] доступно " + parsed.length + ": "
                     + parsed.map(function(w) { return w.id }).join(", "))

        root.registryChanged()

        // Перезагружаем только те установленные виджеты, у которых изменился
        // манифест или набор файлов. Правка отдельного QML обрабатывается
        // наблюдателем файла и не пересобирает реестр.
        for (const widget of parsed) {
            if (oldById[widget.id] && oldFingerprints[widget.id] !== widget.fingerprint) {
                console.info("[widgets/registry] манифест изменился: " + widget.id)
                root.widgetChanged(widget.id)
            }
        }

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

        for (const widget of root.widgets) {
            add(widget.manifestPath, widget.id, "manifest")
            add(widget.dir, widget.id, "dir")
            for (const file of widget.files) {
                if (file !== widget.manifestPath)
                    add(file, widget.id, "file")
            }
        }

        root._watcherModel = model
        root._rootWatcherModel = root.searchPaths.slice()
    }

    function onWatchedFile(path: string, id: string, kind: string): void {
        if (kind === "dir" || kind === "manifest") {
            root.scheduleScan()
            return
        }
        root.queueReload(id)
    }

    function queueReload(id: string): void {
        if (!id)
            return
        root._pendingReloadIds[id] = true
        if (!root._reloadScheduled) {
            root._reloadScheduled = true
            reloadTimer.restart()
        }
    }

    function flushReloads(): void {
        const ids = Object.keys(root._pendingReloadIds)
        root._pendingReloadIds = ({})
        root._reloadScheduled = false
        for (const id of ids) {
            console.info("[widgets/registry] QML изменился: " + id)
            root.widgetChanged(id)
        }
    }

    // --- Валидация манифеста (раздел 3) ---
    function validateManifest(manifest: var, raw: var, files: var): var {
        const errors = []
        if (!manifest || typeof manifest !== "object")
            return { ok: false, errors: ["manifest.json должен быть объектом"] }

        if (manifest.schema !== 1)
            errors.push("schema должен быть 1")

        const id = typeof manifest.id === "string" ? manifest.id.trim() : ""
        if (id.length === 0 || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) || id.indexOf(".") < 0)
            errors.push("id обязателен и должен быть обратным DNS (например, com.example.clock)")

        const name = typeof manifest.name === "string" ? manifest.name.trim() : ""
        if (name.length === 0)
            errors.push("name обязателен")

        const size = root.parseSizeSpec(manifest.size)
        if (!size.ok)
            errors.push(size.error)

        const entryName = typeof manifest.entry === "string" && manifest.entry.trim().length > 0
                        ? manifest.entry.trim() : "Main.qml"
        if (entryName.startsWith("/") || entryName.indexOf("..") >= 0
            || entryName.indexOf("\\") >= 0)
            errors.push("entry должен быть относительным путём внутри папки виджета")
        const entryPath = raw.dir + "/" + entryName
        if (files.indexOf(entryPath) < 0)
            errors.push("entry не найден: " + entryName)

        if (errors.length > 0)
            return { ok: false, errors: errors }

        let colorModes = ["accent", "widget"]
        if (Array.isArray(manifest.colorModes)) {
            const filtered = []
            for (const mode of manifest.colorModes) {
                if ((mode === "accent" || mode === "widget")
                    && filtered.indexOf(mode) < 0)
                    filtered.push(mode)
            }
            if (filtered.length > 0)
                colorModes = filtered
        }

        let materials = ["any"]
        if (Array.isArray(manifest.materials) && manifest.materials.length > 0) {
            const filtered = []
            for (const material of manifest.materials) {
                if (typeof material === "string" && filtered.indexOf(material) < 0)
                    filtered.push(material)
            }
            if (filtered.length > 0)
                materials = filtered
        }

        const settings = root.parseSettings(manifest.settings, id)

        return {
            ok: true,
            widget: {
                id: id,
                name: name,
                description: typeof manifest.description === "string" ? manifest.description : "",
                version: typeof manifest.version === "string" ? manifest.version : "",
                author: typeof manifest.author === "string" ? manifest.author : "",
                icon: typeof manifest.icon === "string" ? manifest.icon : "widgets",
                dir: raw.dir,
                manifestPath: raw.path,
                entryPath: entryPath,
                entryUrl: root.pathToUrl(entryPath),
                sizeSpec: size.spec,
                settingsSchema: settings,
                materials: materials,
                colorModes: colorModes,
                palette: (manifest.palette && typeof manifest.palette === "object") ? manifest.palette : null,
                builtin: root.isUnder(root.builtinRoot, raw.dir),
                manifest: manifest
            }
        }
    }

    function parseSettings(settings: var, id: string): var {
        if (!Array.isArray(settings))
            return []

        const out = []
        const seen = ({})
        for (const setting of settings) {
            if (!setting || typeof setting !== "object")
                continue
            if (typeof setting.key !== "string" || setting.key.length === 0 || seen[setting.key])
                continue
            const type = setting.type
            if (["bool", "string", "int", "real", "enum", "color"].indexOf(type) < 0)
                continue

            let options = []
            let def = setting.default
            if (type === "enum") {
                if (!Array.isArray(setting.options) || setting.options.length === 0)
                    continue
                for (const option of setting.options) {
                    if (typeof option === "string" || typeof option === "number")
                        options.push(option)
                }
                if (options.length === 0)
                    continue
                if (options.indexOf(def) < 0)
                    def = options[0]
            } else if (type === "bool") {
                def = def === true
            } else if (type === "int") {
                def = Number.isFinite(def) ? Math.round(def) : 0
                if (Number.isFinite(setting.min))
                    def = Math.max(def, Math.round(setting.min))
                if (Number.isFinite(setting.max))
                    def = Math.min(def, Math.round(setting.max))
            } else if (type === "real") {
                def = Number.isFinite(def) ? def : 0
                if (Number.isFinite(setting.min))
                    def = Math.max(def, setting.min)
                if (Number.isFinite(setting.max))
                    def = Math.min(def, setting.max)
            } else if (type === "string") {
                def = typeof def === "string" ? def : ""
            } else if (type === "color") {
                def = typeof def === "string" ? def : "#6750A4"
            }

            seen[setting.key] = true
            out.push({
                key: setting.key,
                type: type,
                label: typeof setting.label === "string" ? setting.label : setting.key,
                default: def,
                min: setting.min,
                max: setting.max,
                options: options
            })
        }

        if (settings.length > 0 && out.length === 0)
            console.warn("[widgets/registry] " + id + ": ни одна настройка не прошла валидацию")
        return out
    }

    function parseSizeSpec(size: var): var {
        if (!size || typeof size !== "object")
            return { ok: false, error: "size обязателен" }

        if (Array.isArray(size.allowed)) {
            if (size.allowed.length === 0)
                return { ok: false, error: "size.allowed пуст" }
            const allowed = []
            const seen = ({})
            for (const token of size.allowed) {
                const cell = root.parseCell(token)
                if (!cell)
                    return { ok: false, error: "неверный размер в size.allowed: " + token }
                const key = cell.rows + "x" + cell.cols
                if (seen[key])
                    continue
                seen[key] = true
                allowed.push(cell)
            }
            if (allowed.length === 0)
                return { ok: false, error: "size.allowed пуст" }

            let def = root.parseCell(size.default)
            if (!def)
                def = allowed[0]
            else if (!root.allowedContains(allowed, def.rows, def.cols))
                def = root.nearestAllowed(allowed, def.rows, def.cols)

            const spec = {
                kind: "list",
                allowed: allowed,
                defaultSize: def,
                scalable: allowed.length > 1
            }
            spec.fits = function(rows, cols) {
                return root.allowedContains(this.allowed, rows, cols)
            }
            spec.normalize = function(rows, cols) {
                return this.fits(rows, cols) ? { rows: rows, cols: cols }
                                            : root.nearestAllowed(this.allowed, rows, cols)
            }
            return { ok: true, spec: spec }
        }

        const min = root.parseCell(size.min)
        const max = root.parseCell(size.max)
        if (!min || !max)
            return { ok: false, error: "size.min и size.max обязательны (формат YxX)" }
        if (min.rows > max.rows || min.cols > max.cols)
            return { ok: false, error: "size.min больше size.max" }

        let def = root.parseCell(size.default)
        if (!def)
            def = { rows: min.rows, cols: min.cols }
        def = {
            rows: Math.max(min.rows, Math.min(max.rows, def.rows)),
            cols: Math.max(min.cols, Math.min(max.cols, def.cols))
        }

        const spec = {
            kind: "range",
            minSize: min,
            maxSize: max,
            defaultSize: def,
            scalable: min.rows !== max.rows || min.cols !== max.cols
        }
        spec.fits = function(rows, cols) {
            return rows >= this.minSize.rows && rows <= this.maxSize.rows
                && cols >= this.minSize.cols && cols <= this.maxSize.cols
        }
        spec.normalize = function(rows, cols) {
            return {
                rows: Math.max(this.minSize.rows, Math.min(this.maxSize.rows, rows)),
                cols: Math.max(this.minSize.cols, Math.min(this.maxSize.cols, cols))
            }
        }
        return { ok: true, spec: spec }
    }

    function parseCell(token: var): var {
        if (typeof token !== "string")
            return null
        const parts = token.trim().toLowerCase().split(/[x*]/)
        if (parts.length !== 2)
            return null
        const rows = parseInt(parts[0], 10)
        const cols = parseInt(parts[1], 10)
        if (!Number.isInteger(rows) || !Number.isInteger(cols) || rows < 1 || cols < 1)
            return null
        return { rows: rows, cols: cols }
    }

    function allowedContains(allowed: var, rows: int, cols: int): bool {
        for (const size of allowed) {
            if (size.rows === rows && size.cols === cols)
                return true
        }
        return false
    }

    function nearestAllowed(allowed: var, rows: int, cols: int): var {
        let best = allowed[0]
        let bestDistance = Number.MAX_VALUE
        let bestArea = Number.MAX_VALUE
        for (const size of allowed) {
            const dr = size.rows - rows
            const dc = size.cols - cols
            const distance = dr * dr + dc * dc
            const area = Math.abs(size.rows * size.cols - rows * cols)
            if (distance < bestDistance
                || (distance === bestDistance && area < bestArea)) {
                best = size
                bestDistance = distance
                bestArea = area
            }
        }
        return { rows: best.rows, cols: best.cols }
    }

    // --- Утилиты путей ---
    function expandPath(path: string): string {
        let value = String(path).trim()
        if (value.length === 0)
            return ""
        if (value === "~")
            value = root.home
        else if (value.startsWith("~/"))
            value = root.home + value.slice(1)
        if (!value.startsWith("/"))
            value = (Quickshell.workingDirectory || "") + "/" + value
        if (value.length > 1 && value.endsWith("/"))
            value = value.slice(0, -1)
        return value
    }

    function rootFor(path: string): string {
        const roots = root.searchPaths
        for (const candidate of roots) {
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

    // --- Процессы и наблюдатели ---
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
        id: manifestReaderComponent

        FileView {
            id: manifestReader

            property string manifestPath: ""

            path: manifestReader.manifestPath
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

    onSearchPathsChanged: scheduleScan()

    Component.onCompleted: scheduleScan()
}
