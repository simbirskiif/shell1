pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Источник обоев для материала glass.
//
// Сначала берётся wallpaper из конфига shell; если он пуст — спрашиваем
// hyprpaper. Это единственная зависимость от композитора в проекте; если
// hyprpaper нет, glass просто покажет тонированную подложку без картинки.
Singleton {
    id: root

    readonly property string configured: Config.wallpaper || ""
    property string detected: ""

    function looksLikePath(value: string): bool {
        return value.startsWith("/") || value.startsWith("file://")
    }

    readonly property string path: {
        if (root.configured.length > 0)
            return root.configured
        return root.looksLikePath(root.detected) ? root.detected : ""
    }
    readonly property string sourceUrl: path.length > 0 ? root.pathToUrl(path) : ""

    function pathToUrl(value: string): string {
        if (value.startsWith("file://"))
            return value
        return "file://" + value.split("/").map(function(part) {
            return encodeURIComponent(part)
        }).join("/")
    }

    function fromConfigText(text: string): void {
        if (root.configured.length > 0 || root.looksLikePath(root.detected))
            return
        const match = text.match(/^\s*path\s*=\s*(.+)$/m)
        if (match && root.looksLikePath(match[1].trim()))
            root.detected = match[1].trim()
    }

    Process {
        id: query

        command: ["hyprctl", "hyprpaper", "listactive"]

        stdout: SplitParser {
            onRead: line => {
                if (root.configured.length > 0 || root.detected.length > 0)
                    return
                const marker = line.indexOf(": ")
                if (marker > 0) {
                    const value = line.slice(marker + 2).trim()
                    if (root.looksLikePath(value))
                        root.detected = value
                }
            }
        }
    }

    // hyprpaper хранит путь в конфиге; этот вариант работает и без IPC.
    FileView {
        id: paperConfig

        path: (Quickshell.env("HOME") || "") + "/.config/hypr/hyprpaper.conf"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.fromConfigText(paperConfig.text())

        onFileChanged: {
            if (root.configured.length === 0) {
                root.detected = ""
                reload()
            }
        }
    }

    onSourceUrlChanged: console.info("[widgets/wallpaper] " + root.sourceUrl)

    Component.onCompleted: {
        if (root.configured.length > 0)
            return
        try {
            paperConfig.waitForJob()
            const text = paperConfig.text()
            console.info("[widgets/wallpaper] конфиг " + paperConfig.path
                         + " (" + text.length + " байт)")
            root.fromConfigText(text)
        } catch (e) {
            console.info("[widgets/wallpaper] конфиг не прочитан: " + e)
        }
        query.running = true
    }
}
