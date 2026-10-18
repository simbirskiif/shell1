pragma Singleton

import QtQuick
import Quickshell

// Единая точка правды для цветов, размеров, таймингов и кривых движения.
// Цвета приходят из Wal (pywal с откатом на стандартную палитру),
// производные оттенки считаются здесь, в разметке магических значений нет.
Singleton {
    id: root

    // Бар
    readonly property int barHeight: 44
    readonly property int barPadding: 12
    readonly property color barBackground: withAlpha(darken(neutralize(Wal.background, 0.6), 0.7), 0.90)
    readonly property color barForeground: Wal.foreground

    // Часы
    readonly property int clockFontSize: 13

    // Рабочие столы
    readonly property int workspaceDotSize: 6
    readonly property int workspaceActiveDotSize: 10
    readonly property int workspaceSpacing: 8
    readonly property color workspaceActiveColor: Wal.accent
    readonly property color workspaceInactiveColor: withAlpha(Wal.foreground, 0.45)

    // Кнопка статуса в баре
    readonly property int controlHeight: 30
    readonly property int controlRadius: 10

    // Попап быстрых настроек: ширина общая для всех видов и ограничена.
    readonly property int quickWidth: 400
    readonly property int quickRadius: 18
    readonly property int quickPadding: 12
    readonly property int quickCircleSize: 32
    readonly property int quickTileHeight: 60
    readonly property int quickTileRadius: 14
    readonly property int quickTileSpacing: 8
    readonly property int quickHeaderHeight: 46
    readonly property int quickRowHeight: 44
    readonly property int quickSectionHeight: 28

    // Карточки уведомлений и Центр уведомлений.
    readonly property int notificationWidth: 360
    readonly property int notificationCenterWidth: 400
    readonly property int notificationRadius: 16
    readonly property int notificationPadding: 12
    readonly property int notificationSpacing: 8

    readonly property color accent: Wal.accent

    // --- Material-роли для системы виджетов -------------------------------
    // Виджеты используют тот же Wal-акцент и нейтральную базу, что панели
    // оболочки, поэтому рабочий стол не выбивается из оформления.
    readonly property bool isDark: root.relativeLuminance(Wal.background) < 0.55
    readonly property color widgetSurface:
        withAlpha(mix(neutralSurface, Wal.background, 0.07), 0.97)

    readonly property var colors: ({
        surface: root.widgetSurface,
        onSurface: Wal.foreground,
        surfaceVariant: mix(neutralSurface, Wal.foreground, 0.10),
        onSurfaceVariant: withAlpha(Wal.foreground, 0.65),
        primary: Wal.accent,
        onPrimary: root.relativeLuminance(Wal.accent) > 0.55 ? "#151519" : "#ffffff",
        primaryContainer: mix(neutralSurface, Wal.accent, 0.22),
        onPrimaryContainer: Wal.foreground,
        secondary: mix(neutralSurface, Wal.accent, 0.10),
        onSecondary: Wal.foreground,
        tertiary: mix(Wal.background, Wal.accent, 0.35),
        outline: withAlpha(Wal.foreground, 0.18),
        error: lowColor
    })

    function relativeLuminance(color) {
        if (!color)
            return 0
        const channel = function(value) {
            return value <= 0.03928 ? value / 12.92
                                     : Math.pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g)
             + 0.0722 * channel(color.b)
    }

    function colorsFor(mode, widget) {
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

    // Панели быстрых настроек намеренно почти нейтральные: тёмная база
    // фиксированная, от обоев остаётся лишь лёгкий оттенок.
    readonly property color neutralSurface: "#151519"
    readonly property color quickBackground: withAlpha(mix(neutralSurface, Wal.background, 0.08), 0.98)
    readonly property color quickBorder: withAlpha(Wal.foreground, 0.08)
    readonly property color quickTile: withAlpha(Wal.foreground, 0.04)
    readonly property color quickTileHover: withAlpha(Wal.foreground, 0.08)
    readonly property color quickTileActive: withAlpha(Wal.accent, 0.12)
    readonly property color quickCircleOff: withAlpha(Wal.foreground, 0.10)
    readonly property color quickSwitchOff: withAlpha(Wal.foreground, 0.20)
    readonly property color quickSeparator: withAlpha(Wal.foreground, 0.08)
    readonly property color quickText: Wal.foreground

    // Контекстное меню висит поверх произвольного окна, поэтому его подложка
    // плотнее панелей: полупрозрачный фон сливался с тёмными приложениями.
    readonly property color menuSurface: mix(neutralSurface, "#ffffff", 0.08)
    readonly property color menuBorder: withAlpha(Wal.foreground, 0.20)
    readonly property color quickTextDim: withAlpha(Wal.foreground, 0.55)
    readonly property color quickIconOn: neutralSurface

    // Цвета состояний батареи (как в статус-баре Android).
    readonly property color chargeColor: "#3ddc84"
    readonly property color lowColor: "#e5484d"
    readonly property color mediumColor: "#f5c518"

    // Плашки-предупреждения внутри панелей (нет backend, недоступна функция).
    readonly property color warningColor: "#f2b23c"

    // --- Material 3 motion -------------------------------------------------
    // Длительности из m3 (short/medium) и кривые emphasized/standard.
    readonly property int motionShort3: 150
    readonly property int motionShort4: 200
    readonly property int motionMedium1: 250
    readonly property int motionMedium2: 300
    readonly property int motionLong1: 450

    // Свайп карточки уведомления: улёт за край (accelerate) и упругий
    // возврат (decelerate). Кривые — curveEmphasizedAccelerate/Decelerate.
    readonly property int motionSwipeExit: 150
    readonly property int motionSwipeReturn: 250

    readonly property var curveEmphasized: [0.2, 0.0, 0.0, 1.0]
    readonly property var curveEmphasizedDecelerate: [0.05, 0.7, 0.1, 1.0]
    readonly property var curveEmphasizedAccelerate: [0.3, 0.0, 0.8, 0.15]
    readonly property var curveStandard: [0.2, 0.0, 0.0, 1.0]
    readonly property var curveStandardDecelerate: [0.0, 0.0, 0.0, 1.0]
    readonly property var curveStandardAccelerate: [0.3, 0.0, 1.0, 1.0]

    // Fade through: уходящий вид гаснет за первые 30% времени,
    // приходящий проявляется в оставшиеся 70% (m3 transition patterns).
    readonly property real motionFadeOutShare: 0.3

    // Масштабы входа/выхода: 92% у видов (fade through) и 80% у элементов
    // списков (m3 enter/exit), чтобы переходы читались одинаково.
    readonly property real motionFadeThroughScale: 0.92
    readonly property real motionElementScale: 0.8

    // Жест «назад»: за пальцем вид едет лишь на четверть ширины, остальное
    // делают прозрачность и масштаб — иначе в середине жеста оба вида
    // оказываются за краями панели и смотреть не на что.
    readonly property real gestureParallax: 0.25

    // Шрифты: интерфейс — Google Sans, глифы-иконки — Nerd Font.
    readonly property string fontFamily: "Google Sans"
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"

    function withAlpha(color, alpha) {
        if (!color)
            return Qt.rgba(0, 0, 0, alpha);
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // Подмешивает к цвету серый той же яркости: amount 1 — полностью серый.
    function neutralize(color, amount) {
        if (!color)
            return Qt.rgba(0.1, 0.1, 0.11, 1);
        const luma = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
        return Qt.rgba(color.r + (luma - color.r) * amount,
                       color.g + (luma - color.g) * amount,
                       color.b + (luma - color.b) * amount,
                       color.a);
    }

    function darken(color, factor) {
        if (!color)
            return Qt.rgba(0, 0, 0, 1);
        return Qt.rgba(color.r * factor, color.g * factor, color.b * factor, color.a);
    }

    function mix(a, b, t) {
        if (!a)
            return b;
        if (!b)
            return a;
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }
}
