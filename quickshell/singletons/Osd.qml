pragma Singleton

import QtQuick
import Quickshell

// Всплывающий индикатор громкости и яркости внизу экрана.
//
// Показывается сам при изменении значения — в том числе снаружи: клавиши
// мультимедиа, кнопки на мониторе, чужие утилиты. Поэтому сервисы про него
// ничего не знают, а индикатор просто следит за их публичными значениями.
//
// Первые секунды после старта молчим: при синхронизации значения приезжают
// из нуля, и это не действие пользователя.
Singleton {
    id: root

    property bool shown: false
    // "volume" | "input" | "brightness"
    property string kind: ""
    property string title: ""
    property bool muted: false
    property real value: 0

    // Значения только синхронизировались — пользователь ещё ничего не менял.
    property bool armed: false

    function show(kind, title, value, muted) {
        if (!root.armed)
            return;
        root.kind = kind;
        root.title = title;
        root.muted = muted;
        root.value = Math.max(0, Math.min(1, value));
        root.shown = true;
        // Новое изменение продлевает показ, а не мигает заново.
        hideTimer.restart();
    }

    function hide() {
        root.shown = false;
    }

    function copyMap(map) {
        const next = {};
        for (const key in map)
            next[key] = map[key];
        return next;
    }

    Timer {
        id: armTimer
        interval: 3000
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.hide()
    }

    // ───────────── звук ─────────────

    Connections {
        target: AudioService

        function onOutputVolumeChanged() {
            root.show("volume", "Громкость", AudioService.outputVolume, AudioService.outputMuted);
        }

        function onOutputMutedChanged() {
            root.show("volume", "Громкость", AudioService.outputVolume, AudioService.outputMuted);
        }

        function onInputVolumeChanged() {
            root.show("input", "Микрофон", AudioService.inputVolume, AudioService.inputMuted);
        }

        function onInputMutedChanged() {
            root.show("input", "Микрофон", AudioService.inputVolume, AudioService.inputMuted);
        }
    }

    // ───────────── яркость ─────────────
    // Значения — карта по целям (свой экран / внешний монитор): индикатор
    // показывает именно тот экран, у которого изменилось значение.

    property var brightnessSnapshot: ({})

    Connections {
        target: BrightnessService

        function onValuesChanged() {
            const values = BrightnessService.values;
            if (!root.armed) {
                root.brightnessSnapshot = root.copyMap(values);
                return;
            }
            let changedKey = "";
            for (const key in values) {
                const before = root.brightnessSnapshot[key];
                if (before !== undefined && Math.abs(before - values[key]) > 0.0005) {
                    changedKey = key;
                    break;
                }
            }
            root.brightnessSnapshot = root.copyMap(values);
            if (changedKey === "")
                return;
            const target = BrightnessService.targetByKey(changedKey);
            root.show("brightness", target !== null ? "Яркость · " + target.label : "Яркость",
                      values[changedKey], false);
        }
    }

    Component.onCompleted: root.brightnessSnapshot = root.copyMap(BrightnessService.values)
}
