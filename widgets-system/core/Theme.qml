pragma Singleton

import QtQuick
import Quickshell

// Палитра shell (раздел 6.2 ТЗ).
//
// Пока это базовая светлая/тёмная схема Material 3: этап 3 добавит выбор
// режима accent/widget, генерацию из обоев и пользовательские палитры.
// Публичные роли перечислены в разделе 3.5 ТЗ; виджеты видят их через
// ctx.colors и не должны зависеть от оттенков за пределами этого набора.
Singleton {
    id: root

    readonly property bool isDark: Config.theme !== "light"

    readonly property var lightColors: ({
        surface: "#FFFBFE",
        onSurface: "#1C1B1F",
        surfaceVariant: "#E7E0EC",
        onSurfaceVariant: "#49454F",
        primary: "#6750A4",
        onPrimary: "#FFFFFF",
        primaryContainer: "#EADDFF",
        onPrimaryContainer: "#21005D",
        secondary: "#625B71",
        onSecondary: "#FFFFFF",
        tertiary: "#7D5260",
        outline: "#79747E",
        error: "#B3261E"
    })

    readonly property var darkColors: ({
        surface: "#1C1B1F",
        onSurface: "#E6E1E5",
        surfaceVariant: "#49454F",
        onSurfaceVariant: "#CAC4D0",
        primary: "#D0BCFF",
        onPrimary: "#381E72",
        primaryContainer: "#4F378B",
        onPrimaryContainer: "#EADDFF",
        secondary: "#CCC2DC",
        onSecondary: "#332D41",
        tertiary: "#EFB8C8",
        outline: "#938F99",
        error: "#F2B8B5"
    })

    readonly property var colors: isDark ? darkColors : lightColors

    // Палитра для конкретного режима (раздел 6.3 ТЗ). В режиме widget
    // недостающие роли берутся из палитры shell, чтобы виджет не ломался.
    function colorsFor(mode: string, widget: var): var {
        if (mode !== "widget" || !widget || !widget.palette)
            return root.colors

        const scheme = root.isDark ? widget.palette.dark : widget.palette.light
        if (!scheme || typeof scheme !== "object")
            return root.colors

        const merged = ({})
        for (const key in root.colors)
            merged[key] = root.colors[key]
        for (const key in scheme) {
            if (typeof scheme[key] === "string" && scheme[key].length > 0)
                merged[key] = scheme[key]
        }
        return merged
    }
}
