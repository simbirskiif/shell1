pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Кто сейчас пользуется микрофоном, камерой и геолокацией.
//
// Микрофон и камера-потоки читаются из PipeWire нативно: узел-поток
// появляется, когда приложение открыло устройство, и исчезает, когда
// закрыло. Для захвата системного звука (monitor) поток помечен
// stream.capture.sink — это не микрофон, поэтому он не считается.
//
// Камера, открытая напрямую через V4L2 (браузер, Chrome), и геолокация
// GeoClue2 в API Quickshell отсутствуют — их присылает helper
// (scripts/qs-privacy-helper.py). Процесс helper'а живёт в дереве оболочки
// (PrivacyHelperHost): внутри pragma Singleton Process не запускается.
Singleton {
    id: root

    // ───────────── PipeWire: микрофон и камера ─────────────

    // Без трекера у узлов нет properties, а именно по ним отличаются
    // микрофон, monitor и поток камеры.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property var nodes: Pipewire.nodes.values

    function nodeProperties(node) {
        return node !== null && node !== undefined && node.properties
            ? node.properties : ({});
    }

    function nodeClass(node) {
        return String(root.nodeProperties(node)["media.class"] || "");
    }

    // Захват микрофона приложением: входной аудиопоток, который не пишет
    // системный звук и не поставлен на паузу.
    function isMicrophoneStream(node) {
        if (node === null || node === undefined || !node.isStream)
            return false;
        if (root.nodeClass(node) !== "Stream/Input/Audio")
            return false;
        const properties = root.nodeProperties(node);
        if (String(properties["stream.capture.sink"] || "") === "true")
            return false;
        // pulse.corked — пауза потока: устройство приложением не читается.
        if (String(properties["pulse.corked"] || "false") === "true")
            return false;
        return true;
    }

    // У видеоузлов Quickshell не выставляет isStream (флаг считается только
    // для аудио), поэтому поток камеры отличаем по media.class.
    function isCameraStream(node) {
        return node !== null && node !== undefined
            && root.nodeClass(node) === "Stream/Input/Video";
    }

    // Камера присутствует на шине, даже если её никто не открыл.
    function isCameraDevice(node) {
        return node !== null && node !== undefined && !node.isStream
            && root.nodeClass(node) === "Video/Source";
    }

    readonly property var microphoneStreams: root.nodes.filter(
        node => root.isMicrophoneStream(node))
    readonly property var cameraStreams: root.nodes.filter(
        node => root.isCameraStream(node))
    readonly property var cameraDevices: root.nodes.filter(
        node => root.isCameraDevice(node))

    // ───────────── состояние helper'а ─────────────

    property bool helperOnline: false
    property bool helperCameraAvailable: false
    property bool helperCameraActive: false
    property var helperCameraApps: []
    property bool helperLocationAvailable: false
    property bool helperLocationActive: false

    function consumeHelperLine(line) {
        let data = null;
        try {
            data = JSON.parse(line);
        } catch (error) {
            console.warn("[privacy] не удалось разобрать строку helper'а:", line);
            return;
        }
        if (data === null || typeof data !== "object")
            return;
        root.helperOnline = true;
        if (typeof data.cameraAvailable === "boolean")
            root.helperCameraAvailable = data.cameraAvailable;
        if (typeof data.cameraActive === "boolean")
            root.helperCameraActive = data.cameraActive;
        if (Array.isArray(data.cameraApps))
            root.helperCameraApps = data.cameraApps.map(name => String(name));
        if (typeof data.locationAvailable === "boolean")
            root.helperLocationAvailable = data.locationAvailable;
        if (typeof data.locationActive === "boolean")
            root.helperLocationActive = data.locationActive;
    }

    // Helper упал или перезапускается: старое «камера используется» не
    // должно висеть в баре вечно.
    function clearHelperState() {
        root.helperOnline = false;
        root.helperCameraAvailable = false;
        root.helperCameraActive = false;
        root.helperCameraApps = [];
        root.helperLocationAvailable = false;
        root.helperLocationActive = false;
    }

    // ───────────── подписи ─────────────

    function applicationName(node) {
        const properties = root.nodeProperties(node);
        const app = String(properties["application.name"] || "");
        if (app !== "")
            return app;
        const binary = String(properties["application.process.binary"] || "");
        if (binary !== "")
            return binary;
        if (node !== null && node !== undefined && node.description)
            return String(node.description);
        return node !== null && node !== undefined ? String(node.name) : "";
    }

    // Одно приложение может держать несколько потоков; в панели имя
    // показываем один раз. Сравнение без регистра: helper отдаёт имя
    // процесса («chrome»), PipeWire — application.name («Chrome»).
    function uniqueNames(list) {
        const seen = ({});
        const result = [];
        for (let i = 0; i < list.length; ++i) {
            const name = String(list[i] || "").trim();
            if (name === "")
                continue;
            const key = name.toLowerCase();
            if (seen[key])
                continue;
            seen[key] = true;
            result.push(name);
        }
        return result;
    }

    readonly property var microphoneApps: root.uniqueNames(
        root.microphoneStreams.map(node => root.applicationName(node)))

    readonly property var cameraApps: root.uniqueNames(
        root.cameraStreams.map(node => root.applicationName(node))
            .concat(root.helperCameraApps))

    // ───────────── итоговые флаги ─────────────

    readonly property bool microphoneAvailable: AudioService.inputDevices.length > 0
    readonly property bool microphoneActive: root.microphoneStreams.length > 0

    readonly property bool cameraAvailable: root.cameraDevices.length > 0
        || root.cameraStreams.length > 0
        || root.helperCameraAvailable
    readonly property bool cameraActive: root.cameraStreams.length > 0
        || root.helperCameraActive

    readonly property bool locationAvailable: root.helperLocationAvailable
    readonly property bool locationActive: root.helperLocationActive

    readonly property bool anyActive: root.microphoneActive || root.cameraActive
        || root.locationActive
    readonly property bool anyAvailable: root.microphoneAvailable
        || root.cameraAvailable || root.locationAvailable

    // Короткий статус для панели: «In use — Firefox», «In use», …
    function statusText(apps) {
        return apps.length > 0 ? "In use — " + apps.join(", ") : "In use";
    }

    readonly property string microphoneStatus: {
        if (!root.microphoneAvailable)
            return "No microphone";
        return root.microphoneActive
            ? root.statusText(root.microphoneApps)
            : "Not in use";
    }

    readonly property string cameraStatus: {
        if (!root.cameraAvailable)
            return "No camera";
        return root.cameraActive
            ? root.statusText(root.cameraApps)
            : "Not in use";
    }

    readonly property string locationStatus: {
        if (!root.locationAvailable)
            return "GeoClue is not available";
        return root.locationActive ? "In use" : "Not in use";
    }
}

