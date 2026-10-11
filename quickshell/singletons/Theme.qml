pragma Singleton

import QtQuick
import Quickshell

// Единая точка правды для цветов, размеров и таймингов оболочки.
// Цвета взяты из текущей pywal-палитры (~/.cache/wal/colors.json),
// чтобы бар не выбивался из остального рабочего стола.
Singleton {
    // Бар
    readonly property int barHeight: 44
    readonly property int barPadding: 12
    readonly property color barBackground: "#cc1e1a18"
    readonly property color barForeground: "#c9c6c5"

    // Часы
    readonly property int clockFontSize: 13

    // Рабочие столы
    readonly property int workspaceDotSize: 6
    readonly property int workspaceActiveDotSize: 10
    readonly property int workspaceSpacing: 8
    readonly property color workspaceActiveColor: "#0a9ee2"
    readonly property color workspaceInactiveColor: "#796863"

    // Анимации
    readonly property int animationDuration: 180
    readonly property int animationEasing: Easing.OutCubic

    // Шрифт
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
