pragma Singleton

import QtQuick
import Quickshell

// Единая точка правды для цветов, размеров и таймингов оболочки.
// Цвета приходят из Palette (pywal с откатом на стандартную палитру),
// производные оттенки считаются здесь, в разметке магических цветов нет.
Singleton {
    // Бар
    readonly property int barHeight: 44
    readonly property int barPadding: 12
    readonly property color barBackground: withAlpha(Wal.background, 0.80)
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

    readonly property color accent: Wal.accent
    // Фон попапа заметно темнее и почти нейтральный: оттенок палитры
    // сохраняем чуть-чуть, чтобы панель не спорила с обоями.
    readonly property color quickBackground: withAlpha(darken(neutralize(Wal.background, 0.9), 0.6), 0.97)
    readonly property color quickBorder: withAlpha(Wal.foreground, 0.10)
    readonly property color quickTile: withAlpha(Wal.foreground, 0.06)
    readonly property color quickTileHover: withAlpha(Wal.foreground, 0.11)
    readonly property color quickTileActive: withAlpha(Wal.accent, 0.22)
    readonly property color quickCircleOff: withAlpha(Wal.foreground, 0.13)
    readonly property color quickSwitchOff: withAlpha(Wal.foreground, 0.22)
    readonly property color quickSeparator: withAlpha(Wal.foreground, 0.10)
    readonly property color quickText: Wal.foreground
    readonly property color quickTextDim: withAlpha(Wal.foreground, 0.55)
    readonly property color quickIconOn: Wal.background

    // Анимации: окно и смена вида — резкие (OutQuint), мелочи — короткие.
    readonly property int animationDuration: 180
    readonly property int animationEasing: Easing.OutCubic
    readonly property int quickWindowDuration: 190
    readonly property int quickWindowEasing: Easing.OutQuint
    readonly property int quickViewDuration: 160
    readonly property int quickViewEasing: Easing.OutQuint
    readonly property int quickHoverDuration: 110
    readonly property real quickIdleScale: 0.94

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
}
