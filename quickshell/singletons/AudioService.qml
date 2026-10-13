pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Реальный backend звука поверх PipeWire (Quickshell.Services.Pipewire).
//
// Источник истины — PipeWire/WirePlumber: сервис ничего не хранит и не
// опрашивает таймером, а читает состояние узлов и пишет громкость/mute прямо
// в узел. События приходят от самого PipeWire.
//
// Почему трекер обязателен: без привязки объекты PipeWire доступны лишь
// частично — у узла нет audio, и громкость ни прочитать, ни изменить.
// PwObjectTracker привязывает все узлы, поэтому состояние живое.
//
// Слои:
//   * узлы — все узлы PipeWire, разложенные на устройства и потоки;
//   * устройства — sinks (вывод) и sources (вход) без потоков;
//   * потоки приложений — isStream с аудио (воспроизведение);
//   * действия — setOutputVolume/toggleOutputMute/setNodeVolume/…;
//   * выбор устройства — preferredDefaultAudioSink/Source.
Singleton {
    id: root

    // ───────────── привязка объектов ─────────────

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // ───────────── доступность ─────────────
    // ready — Quickshell завершил первичную синхронизацию с сервером.
    // Если PipeWire не запущен, ready не станет true, и панель покажет
    // заглушку вместо пустых списков.
    readonly property bool available: Pipewire.ready

    // ───────────── узлы ─────────────

    readonly property var nodes: Pipewire.nodes.values

    function hasAudio(node) {
        return node !== null && node !== undefined
            && node.audio !== null && node.audio !== undefined;
    }

    // Устройство вывода: аудио-узел, не поток, принимает звук (колонки, HDMI).
    function isOutputDevice(node) {
        return root.hasAudio(node) && !node.isStream && node.isSink;
    }

    // Устройство ввода: аудио-узел, не поток, отдаёт звук (микрофон).
    function isInputDevice(node) {
        return root.hasAudio(node) && !node.isStream && !node.isSink;
    }

    // Поток воспроизведения приложения: узел-поток, принимающий звук.
    function isPlaybackStream(node) {
        return root.hasAudio(node) && node.isStream && node.isSink;
    }

    // Списки пересчитываются только при появлении/исчезновении узлов:
    // смена громкости их не трогает, поэтому делегаты не пересоздаются.
    readonly property var outputDevices: nodes.filter(n => root.isOutputDevice(n))
    readonly property var inputDevices: nodes.filter(n => root.isInputDevice(n))
    readonly property var streams: nodes.filter(n => root.isPlaybackStream(n))

    // ───────────── устройство по умолчанию ─────────────
    // defaultAudioSink — фактическое устройство; preferredDefaultAudioSink —
    // только пожелание WirePlumber. Для отметки текущего нужно первое.

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    readonly property bool outputMuted: root.hasAudio(defaultSink) ? defaultSink.audio.muted : false
    readonly property real outputVolume: root.hasAudio(defaultSink) ? defaultSink.audio.volume : 0
    readonly property string outputName: root.deviceLabel(defaultSink)

    readonly property bool inputMuted: root.hasAudio(defaultSource) ? defaultSource.audio.muted : false
    readonly property real inputVolume: root.hasAudio(defaultSource) ? defaultSource.audio.volume : 0
    readonly property string inputName: root.deviceLabel(defaultSource)

    // Короткая подпись для плитки: mute важнее процента, а без backend
    // процент был бы обманом — там нечего показывать.
    readonly property string outputSummary: !root.available
        ? "Unavailable"
        : root.outputMuted ? "Muted" : Math.round(root.outputVolume * 100) + "%"

    // ───────────── подписи ─────────────

    // Короткое человеческое имя устройства: nickname («Speaker», «HDMI 3»)
    // читается лучше, чем полное description с моделью звуковой карты.
    function deviceLabel(node) {
        if (node === null || node === undefined)
            return "";
        if (node.nickname !== "")
            return node.nickname;
        if (node.description !== "")
            return node.description;
        return node.name;
    }

    function streamApp(node) {
        if (node === null || node === undefined)
            return "";
        const props = node.properties || {};
        const app = props["application.name"] || props["application.process.binary"] || "";
        if (app !== "")
            return app;
        if (node.description !== "")
            return node.description;
        return node.nickname !== "" ? node.nickname : node.name;
    }

    // media.name — что именно играет; у части приложений он совпадает
    // с именем узла или пуст, тогда подпись не дублируем.
    function streamMedia(node) {
        if (node === null || node === undefined)
            return "";
        const media = (node.properties || {})["media.name"] || "";
        if (media === "" || media === node.name || media === root.streamApp(node))
            return "";
        return media;
    }

    function streamLabel(node) {
        const app = root.streamApp(node);
        const media = root.streamMedia(node);
        if (app === "")
            return media;
        if (media === "")
            return app;
        return app + " — " + media;
    }

    // ───────────── громкость и mute ─────────────

    function setNodeVolume(node, value) {
        if (!root.hasAudio(node))
            return;
        node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setNodeMuted(node, muted) {
        if (!root.hasAudio(node))
            return;
        node.audio.muted = muted;
    }

    function setOutputVolume(value) {
        root.setNodeVolume(root.defaultSink, value);
    }

    function setInputVolume(value) {
        root.setNodeVolume(root.defaultSource, value);
    }

    function toggleOutputMute() {
        root.setNodeMuted(root.defaultSink, !root.outputMuted);
    }

    function toggleInputMute() {
        root.setNodeMuted(root.defaultSource, !root.inputMuted);
    }

    // ───────────── выбор устройства ─────────────

    function setDefaultSink(node) {
        if (node !== null && node !== undefined)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node !== null && node !== undefined)
            Pipewire.preferredDefaultAudioSource = node;
    }

    // Сравнение по id: объект-узел при переподключении PipeWire пересоздаётся.
    function isDefaultSink(node) {
        return root.defaultSink !== null && node !== null && node !== undefined
            && root.defaultSink.id === node.id;
    }

    function isDefaultSource(node) {
        return root.defaultSource !== null && node !== null && node !== undefined
            && root.defaultSource.id === node.id;
    }
}
