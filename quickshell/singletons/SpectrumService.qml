pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Реальный спектр текущего плеера.
//
// Данные приходят не из MPRIS (там нет аудио), а из отдельного процесса:
// scripts/qs-audio-spectrum.py читает монитор дефолтного sink'а через parec
// и считает БПФ, отдавая по строке JSON с уровнями 16 полос. Здесь — запуск
// процесса только когда есть играющий плеер и спектр включён, плюс
// сохранение переключателя.
Singleton {
    id: root

    // Активный плеер: играющий, иначе первый. Та же логика, что у виджета
    // my.player, чтобы окно и иконка говорили об одном плеере.
    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool hasPlayer: root.player !== null
    readonly property bool playing: root.player !== null && root.player.isPlaying

    readonly property int bandCount: 16
    // Уровни 0..1, по одной записи на полосу. Пока данных нет — нули.
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // Спектр можно отключить: тогда процесс не запускается, а иконка
    // показывает обычный значок плеера.
    property bool enabled: true
    property bool restoring: false

    readonly property bool active: root.enabled && root.playing

    onEnabledChanged: {
        if (root.restoring || !Settings.loaded)
            return;
        Settings.setValue("player.spectrumEnabled", root.enabled);
    }

    onActiveChanged: {
        if (!root.active)
            root.bands = root.zeroBands();
    }

    function zeroBands() {
        const values = [];
        for (let i = 0; i < root.bandCount; ++i)
            values.push(0);
        return values;
    }

    function consume(line) {
        try {
            const values = JSON.parse(line);
            if (!Array.isArray(values) || values.length === 0)
                return;
            const normalized = [];
            for (let i = 0; i < root.bandCount; ++i) {
                const value = Number(values[i]);
                normalized.push(Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0);
            }
            root.bands = normalized;
        } catch (error) {
            // Одна битая строка не должна ломать весь поток.
            console.warn("[spectrum] не удалось разобрать строку:", line);
        }
    }

    function restore() {
        root.restoring = true;
        root.enabled = Settings.value("player.spectrumEnabled", true) === true;
        root.restoring = false;
    }

    Connections {
        target: Settings

        function onLoadedChanged() {
            if (Settings.loaded)
                root.restore();
        }
    }

    Component.onCompleted: {
        if (Settings.loaded)
            root.restore();
    }

    Process {
        id: analyzer
        running: root.active
        command: ["python3", Quickshell.shellDir + "/scripts/qs-audio-spectrum.py"]

        stdout: SplitParser {
            onRead: line => root.consume(line)
        }

        stderr: SplitParser {
            // Ошибки helper'а не засоряют лог каждой строкой: parec может
            // ругаться при перезапуске аудиосервера.
            onRead: line => console.warn("[spectrum]", line)
        }
    }
}
