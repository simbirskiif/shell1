pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Палитра оболочки: цвета pywal, если они есть, иначе стандартные.
// pywal кладёт палитру либо в ~/.config/wal/colors.json, либо
// в ~/.cache/wal/colors.json — пробуем оба по порядку.
//
// Значения — обычные свойства (а не вычисляемые биндинги), чтобы палитра
// была валидной сразу и не зависела от порядка инициализации.
Singleton {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")

    // Стандартная палитра — стартовые значения, если pywal недоступен.
    readonly property color fallbackBackground: "#1b1b21"
    readonly property color fallbackForeground: "#f2f2f2"
    readonly property color fallbackAccent: "#0a9ee2"

    property bool walLoaded: false
    property color background: root.fallbackBackground
    property color foreground: root.fallbackForeground
    property color accent: root.fallbackAccent

    function reload() {
        const data = readPalette();
        root.walLoaded = data !== null;
        if (data === null) {
            root.background = root.fallbackBackground;
            root.foreground = root.fallbackForeground;
            root.accent = root.fallbackAccent;
            return;
        }
        root.background = pickSpecial(data, "background", root.fallbackBackground);
        root.foreground = pickSpecial(data, "foreground", root.fallbackForeground);
        root.accent = pickAccent(data);
    }

    function readPalette() {
        const sources = [configFile, cacheFile];
        for (let i = 0; i < sources.length; ++i) {
            const file = sources[i];
            if (!file.loaded)
                continue;
            const text = file.text();
            if (!text)
                continue;
            try {
                return JSON.parse(text);
            } catch (error) {
                console.warn("Wal: не удалось разобрать", file.path, error);
            }
        }
        return null;
    }

    function pickSpecial(data, key, fallback) {
        if (data && data.special) {
            const value = data.special[key];
            if (typeof value === "string")
                return value;
        }
        return fallback;
    }

    // Акцент — самый насыщенный из color1..color6: порядок у pywal
    // не смысловой, а насыщенность даёт «живой» цвет под любые обои.
    function pickAccent(data) {
        if (!data || !data.colors)
            return root.fallbackAccent;
        let best = "";
        let bestSaturation = -1;
        for (let i = 1; i <= 6; ++i) {
            const value = data.colors["color" + i];
            if (typeof value !== "string")
                continue;
            const saturation = hexSaturation(value);
            if (saturation > bestSaturation) {
                bestSaturation = saturation;
                best = value;
            }
        }
        return best !== "" ? best : root.fallbackAccent;
    }

    // Насыщенность HSL по hex-строке "#rrggbb".
    function hexSaturation(hex) {
        if (typeof hex !== "string" || hex.length < 7)
            return 0;
        const r = parseInt(hex.substr(1, 2), 16) / 255;
        const g = parseInt(hex.substr(3, 2), 16) / 255;
        const b = parseInt(hex.substr(5, 2), 16) / 255;
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        if (max === min)
            return 0;
        const lightness = (max + min) / 2;
        return lightness > 0.5 ? (max - min) / (2 - max - min) : (max - min) / (max + min);
    }

    FileView {
        id: configFile
        path: root.configHome + "/wal/colors.json"
        watchChanges: true
        onLoadedChanged: root.reload()
        onFileChanged: root.reload()
    }

    FileView {
        id: cacheFile
        path: root.cacheHome + "/wal/colors.json"
        watchChanges: true
        onLoadedChanged: root.reload()
        onFileChanged: root.reload()
    }

    Component.onCompleted: root.reload()
}
