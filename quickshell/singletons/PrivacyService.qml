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

    // Подпись для строки-индикатора в быстрых настройках.
    readonly property var activeDeviceNames: {
        const names = [];
        if (root.microphoneActive)
            names.push("Microphone");
        if (root.cameraActive)
            names.push("Camera");
        if (root.locationActive)
            names.push("Location");
        return names;
    }
    readonly property string activeSummary: root.activeDeviceNames.join(", ")
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

    // ───────────── остановка захвата ─────────────

    readonly property bool microphoneStoppable: root.microphoneStreams.length > 0
    // Камера, открытая приложением напрямую через V4L2, сюда не попадает:
    // её поток не наш, и отозвать доступ из оболочки нельзя.
    readonly property bool cameraStoppable: root.cameraStreams.length > 0
    // Клиента GeoClue мы не создавали, поэтому не можем его удалить.
    readonly property bool locationStoppable: false

    // Уничтожение потоков выполняет PrivacyHelperHost: Process не живёт
    // в синглтоне.
    signal stopStreamsRequested(var streamIds)

    function stopDevice(device) {
        let ids = [];
        if (device === "microphone")
            ids = root.microphoneStreams.map(node => node.id);
        else if (device === "camera")
            ids = root.cameraStreams.map(node => node.id);
        if (ids.length === 0)
            return;
        root.stopStreamsRequested(ids);
    }

    // ───────────── история использования ─────────────
    // Одна запись — сессия приложения с устройством. Сессии одного
    // устройства с одинаковыми приложениями, между которыми прошло меньше
    // historyMergeGap, склеиваются в один «пакет» (короткие паузы не дробят
    // историю на десятки строк).

    readonly property int historyLimit: 60
    readonly property int historyMergeGap: 30000
    readonly property int historyMinDuration: 2000

    property var history: []
    // Открытые сессии: device -> { start }.
    property var openSessions: ({})
    property bool historyRestoring: false

    // Последние сессии для панели, новые сверху.
    readonly property var recentHistory: root.history.slice(-8).reverse()

    function sameApps(first, second) {
        const a = (first || []).map(name => String(name).toLowerCase()).sort();
        const b = (second || []).map(name => String(name).toLowerCase()).sort();
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; ++i) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function appsFor(device) {
        if (device === "microphone")
            return root.microphoneApps;
        if (device === "camera")
            return root.cameraApps;
        return [];
    }

    // Приложения запоминаем в открытой сессии: когда поток исчезает,
    // microphoneApps/cameraApps уже пусты, и в историю попало бы «-».
    function updateOpenApps(device, apps) {
        const session = root.openSessions[device];
        if (session === undefined || session === null)
            return;
        // При исчезновении потока приложения приходят пустыми — не затираем
        // последнее известное имя на этапе завершения сессии.
        const lastApps = session.apps !== undefined ? session.apps : [];
        const sessions = {};
        for (const key in root.openSessions)
            sessions[key] = root.openSessions[key];
        sessions[device] = { start: session.start,
                             apps: apps.length > 0 ? apps : lastApps };
        root.openSessions = sessions;
    }

    function updateSession(device, active) {
        if (active) {
            const sessions = {};
            for (const key in root.openSessions)
                sessions[key] = root.openSessions[key];
            sessions[device] = { start: Date.now(), apps: root.appsFor(device) };
            root.openSessions = sessions;
            return;
        }

        const session = root.openSessions[device];
        if (session === undefined || session === null)
            return;
        const sessions = {};
        for (const key in root.openSessions) {
            if (key !== device)
                sessions[key] = root.openSessions[key];
        }
        root.openSessions = sessions;

        const now = Date.now();
        const start = Number(session.start);
        if (!Number.isFinite(start) || now - start < root.historyMinDuration)
            return;

        const apps = session.apps !== undefined ? session.apps : root.appsFor(device);
        const next = root.history.slice();
        // Склеиваем только с последней сессией того же устройства: это и есть
        // «пакет», а не слияние всей истории.
        let mergeIndex = -1;
        for (let i = next.length - 1; i >= 0; --i) {
            if (next[i].device !== device)
                continue;
            if (start - Number(next[i].end) <= root.historyMergeGap
                    && root.sameApps(next[i].apps, apps))
                mergeIndex = i;
            break;
        }

        if (mergeIndex >= 0) {
            const merged = {
                device: device,
                apps: apps,
                start: next[mergeIndex].start,
                end: now
            };
            // Пакет снова стал самым свежим: переносим его в конец, чтобы
            // порядок истории совпадал с порядком окончания сессий.
            next.splice(mergeIndex, 1);
            next.push(merged);
        } else {
            next.push({ device: device, apps: apps, start: start, end: now });
            if (next.length > root.historyLimit)
                next.splice(0, next.length - root.historyLimit);
        }
        root.history = next;
        root.storeHistory();
    }

    onMicrophoneActiveChanged: root.updateSession("microphone", root.microphoneActive)
    onCameraActiveChanged: root.updateSession("camera", root.cameraActive)
    onLocationActiveChanged: root.updateSession("location", root.locationActive)

    onMicrophoneAppsChanged: root.updateOpenApps("microphone", root.microphoneApps)
    onCameraAppsChanged: root.updateOpenApps("camera", root.cameraApps)

    function clearHistory() {
        root.history = [];
        if (Settings.loaded)
            Settings.setValue("privacy.history", []);
    }

    function storeHistory() {
        if (root.historyRestoring || !Settings.loaded)
            return;
        Settings.setValue("privacy.history", root.history);
    }

    function restoreHistory() {
        root.historyRestoring = true;
        const saved = Settings.value("privacy.history", []);
        const cleaned = [];
        if (Array.isArray(saved)) {
            for (let i = 0; i < saved.length; ++i) {
                const item = saved[i];
                if (item === null || typeof item !== "object")
                    continue;
                const device = String(item.device || "");
                if (device !== "microphone" && device !== "camera" && device !== "location")
                    continue;
                const start = Number(item.start);
                const end = Number(item.end);
                if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start)
                    continue;
                const apps = Array.isArray(item.apps)
                    ? item.apps.map(name => String(name)) : [];
                cleaned.push({ device: device, apps: apps, start: start, end: end });
            }
        }
        cleaned.sort((first, second) => first.end - second.end);
        if (cleaned.length > root.historyLimit)
            cleaned.splice(0, cleaned.length - root.historyLimit);
        root.history = cleaned;
        root.historyRestoring = false;
    }

    Connections {
        target: Settings

        function onLoadedChanged() {
            if (Settings.loaded)
                root.restoreHistory();
        }
    }

    Component.onCompleted: {
        if (Settings.loaded)
            root.restoreHistory();
    }
}

