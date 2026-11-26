pragma Singleton

import QtQuick
import Quickshell

// Значки системных состояний для бара и быстрых настроек: звук, яркость,
// Bluetooth. Одна точка правды, чтобы кнопка, плитка и составная иконка
// показывали одно и то же.
Singleton {
    id: root

    // --- звук -------------------------------------------------------------
    readonly property bool soundAvailable: AudioService.available
    readonly property real soundVolume: AudioService.outputVolume
    readonly property bool soundMuted: AudioService.outputMuted
    readonly property bool soundAudible: root.soundAvailable && !root.soundMuted
                                         && root.soundVolume > 0.001

    // Громкость: выключено/тихо — перечёркнутый динамик, ниже 60% — тихий,
    // иначе — обычные волны.
    readonly property string soundGlyph: {
        if (!root.soundAudible)
            return "\uf026";
        if (root.soundVolume < 0.60)
            return "\uf027";
        return "\uf028";
    }

    readonly property color soundColor: root.soundAudible ? Theme.scheme.onSurface
                                                           : Theme.quickTextDim

    // --- Bluetooth --------------------------------------------------------
    readonly property bool bluetoothEnabled: BluetoothBackend.enabled
    readonly property bool bluetoothConnected: BluetoothBackend.anyConnected
    readonly property string bluetoothGlyph: "\uf293"
    readonly property color bluetoothColor: !root.bluetoothEnabled
                                            ? Theme.quickTextDim
                                            : (root.bluetoothConnected
                                               ? Theme.primary : Theme.scheme.onSurface)

    // --- яркость ----------------------------------------------------------
    readonly property bool brightnessAvailable: BrightnessService.available
    readonly property real brightnessLevel: BrightnessService.primary
                                            ? BrightnessService.valueFor(
                                                  BrightnessService.primary.key) : 0
    readonly property string brightnessGlyph: root.brightnessGlyphFor(
                                                  root.brightnessLevel,
                                                  root.brightnessAvailable)
    readonly property color brightnessColor: root.brightnessAvailable
                                             ? Theme.scheme.onSurface
                                             : Theme.quickTextDim
    readonly property real brightnessOpacity: root.brightnessOpacityFor(
                                                  root.brightnessLevel,
                                                  root.brightnessAvailable)

    // Для строки конкретного экрана: тот же выбор значка по его значению.
    function brightnessGlyphFor(value, available) {
        if (!available || value < 0.34)
            return "\uf186";
        return "\uf185";
    }

    function brightnessOpacityFor(value, available) {
        if (!available)
            return Theme.disabledContent;
        return 0.55 + 0.45 * Math.max(0, Math.min(1, value));
    }
}
