pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Источник обоев для материалов виджетов и экрана блокировки.
//
// Источник истины — hyprpaper: активные обои спрашиваем у него через IPC
// (`hyprctl hyprpaper listactive`). Файл hyprpaper.conf — только стартовый
// запасной вариант: он легко устаревает (обои меняют через IPC, а конфиг
// остаётся прежним), и именно из-за этого виджеты показывали старый фон.
//
// О смене обоев узнаём по событию Hyprland: hyprpaper пересоздаёт свою
// layer-shell поверхность, и в сокете событий появляются
// closelayer/openlayer с namespace "hyprpaper". Это событие, а не опрос,
// поэтому смена фона подхватывается сразу, без фонового таймера.
//
// Если oboi заданы в конфиге оболочки (Config.wallpaper), они важнее
// hyprpaper: пользователь явно зафиксировал путь.
Singleton {
    id: root

    // Путь из конфига оболочки; пусто — спрашиваем hyprpaper.
    readonly property string configured: Config.wallpaper || ""
    // Последний известный активный путь от hyprpaper.
    property string detected: ""

    property bool querying: false
    property bool queryQueued: false
    // Сколько раз подряд не удался запрос к hyprpaper. Не повторяем вечно:
    // если демона нет, обои просто не показываем.
    property int queryFailures: 0

    function looksLikePath(value: string): bool {
        return value.startsWith("/") || value.startsWith("file://")
    }

    readonly property string path: {
        if (root.configured.length > 0)
            return root.configured
        return root.looksLikePath(root.detected) ? root.detected : ""
    }
    readonly property string sourceUrl: root.path.length > 0 ? root.pathToUrl(root.path) : ""

    function pathToUrl(value: string): string {
        if (value.startsWith("file://"))
            return value
        return "file://" + value.split("/").map(function(part) {
            return encodeURIComponent(part)
        }).join("/")
    }

    // Перечитать активные обои у hyprpaper. Пока запрос уже идёт, новый не
    // запускаем: запомним, что после ответа нужен ещё один.
    function reload(): void {
        if (root.configured.length > 0)
            return
        // Внешний повод (событие, конфиг, IPC) снова даёт право на повторы.
        root.queryFailures = 0
        root.startQuery()
    }

    function startQuery(): void {
        if (root.querying) {
            root.queryQueued = true
            return
        }
        root.queryQueued = false
        root.querying = true
        query.running = true
    }

    // Разбор ответа `hyprctl hyprpaper listactive`:
    //   eDP-1: /home/user/wall.jpg
    //   HDMI-A-1: /home/user/other.jpg
    // либо "no active wallpapers". Предпочитаем обои монитора с фокусом:
    // у виджетов один общий источник, и он должен совпадать с тем, что
    // видит пользователь.
    function applyActive(text: string): void {
        const focused = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : ""
        const lines = String(text || "").split("\n")
        let first = ""
        let preferred = ""
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (line.length === 0)
                continue
            const marker = line.indexOf(": ")
            if (marker <= 0)
                continue
            const monitor = line.slice(0, marker).trim()
            const value = line.slice(marker + 2).trim()
            if (!root.looksLikePath(value))
                continue
            if (first.length === 0)
                first = value
            if (focused.length > 0 && monitor === focused)
                preferred = value
        }
        const found = preferred.length > 0 ? preferred : first
        if (found.length === 0)
            return
        if (root.configured.length > 0)
            return
        if (found !== root.detected)
            root.detected = found
    }

    // Запасной вариант на первый кадр: пока hyprpaper не ответил, берём путь
    // из его конфига, чтобы стекло не оставалось без картинки.
    function fromConfigText(text: string): void {
        if (root.configured.length > 0 || root.detected.length > 0)
            return
        const match = text.match(/^\s*path\s*=\s*(.+)$/m)
        if (match && root.looksLikePath(match[1].trim()))
            root.detected = match[1].trim()
    }

    Process {
        id: query

        command: ["hyprctl", "hyprpaper", "listactive"]

        stdout: StdioCollector {
            id: queryOut

            onStreamFinished: root.applyActive(queryOut.text)
        }
        stderr: StdioCollector {}

        onExited: (code, status) => {
            root.querying = false
            if (code === 0) {
                root.queryFailures = 0
                if (root.queryQueued) {
                    root.queryQueued = false
                    requery.restart()
                }
            } else if (root.queryFailures < 5) {
                root.queryFailures++
                root.queryQueued = false
                queryRetry.restart()
            }
        }
    }

    // Небольшая пауза перед повторным запросом: смена обоев приходит
    // парой событий (closelayer + openlayer), не запрашиваем дважды.
    Timer {
        id: requery

        interval: 150
        repeat: false
        onTriggered: root.reload()
    }

    // hyprpaper мог ответить ошибкой, если его IPC ещё не готов (например,
    // сразу после входа в сессию). Повторяем чуть позже.
    Timer {
        id: queryRetry

        interval: 600
        repeat: false
        onTriggered: root.startQuery()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "openlayer" && event.name !== "closelayer")
                return
            if (event.data !== "hyprpaper")
                return
            requery.restart()
        }
    }

    // hyprpaper перечитывает конфиг при правке — после этого активные обои
    // могли смениться. Слушаем файл как дополнительный триггер.
    FileView {
        id: paperConfig

        path: (Quickshell.env("HOME") || "") + "/.config/hypr/hyprpaper.conf"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.fromConfigText(paperConfig.text())

        onFileChanged: {
            paperConfig.reload()
            requery.restart()
        }
    }

    onSourceUrlChanged: console.info("[widgets/wallpaper] " + root.sourceUrl)

    Component.onCompleted: {
        try {
            paperConfig.waitForJob()
            const text = paperConfig.text()
            console.info("[widgets/wallpaper] конфиг " + paperConfig.path
                         + " (" + text.length + " байт)")
            root.fromConfigText(text)
        } catch (e) {
            console.info("[widgets/wallpaper] конфиг не прочитан: " + e)
        }
        root.reload()
    }
}
