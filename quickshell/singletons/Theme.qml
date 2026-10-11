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

    // Кнопка статуса в баре
    readonly property int controlHeight: 30
    readonly property int controlRadius: 10

    // Попап быстрых настроек
    readonly property int quickWidth: 340
    readonly property int quickDetailWidth: 380
    readonly property int quickRadius: 18
    readonly property int quickPadding: 12
    readonly property int quickTileHeight: 52
    readonly property int quickTileRadius: 14
    readonly property int quickTileSpacing: 8
    readonly property int quickHeaderHeight: 46
    readonly property int quickRowHeight: 44
    readonly property color accent: "#0a9ee2"

    readonly property color quickBackground: "#f21b1b21"
    readonly property color quickBorder: "#1affffff"
    readonly property color quickTile: "#12ffffff"
    readonly property color quickTileHover: "#1fffffff"
    readonly property color quickTileActive: "#330a9ee2"
    readonly property color quickCircleOff: "#26ffffff"
    readonly property color quickSwitchOff: "#3dffffff"
    readonly property color quickSeparator: "#1affffff"
    readonly property color quickText: "#f2f2f2"
    readonly property color quickTextDim: "#8cffffff"
    readonly property color quickIconOn: "#10131a"

    // Анимации
    readonly property int animationDuration: 180
    readonly property int animationEasing: Easing.OutCubic
    readonly property int quickAnimDuration: 260
    readonly property int quickAnimEasing: Easing.OutCubic

    // Шрифт
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
