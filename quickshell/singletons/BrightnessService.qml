pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

// Реальная яркость экранов: по одной записи на каждый экран композитора.
//
// Два способа управления:
//   * встроенная панель — /sys/class/backlight: значение читаем из sysfs
//     (файл доступен на чтение всем), а пишем через logind
//     (org.freedesktop.login1.Session.SetBrightness): прямой write в sysfs
//     требует root или правила udev, а logind разрешает смену яркости
//     владельцу активной сессии;
//   * внешние мониторы по HDMI/DP — DDC/CI через ddcutil: монитор отдаёт
//     яркость по I2C, другого пути нет. Если ddcutil не установлен, экран
//     показывается как неуправляемый с подсказкой.
//
// Связь устройства с экраном — по DRM-коннектору: и путь sysfs, и ddcutil
// называют его card1-eDP-1 / card0-HDMI-A-1, а Quickshell — именем экрана
// (eDP-1, HDMI-A-1). Если коннектор не совпал (например, acpi_video0 его
// вовсе не содержит), работает запасное правило: единственное
// backlight-устройство достаётся внутренней панели.
//
// Слои:
//   * обнаружение — backlight-устройства, DDC-дисплеи, сборка целей;
//   * чтение — FileView по sysfs (следим за изменениями) и ddcutil getvcp;
//   * запись — logind для backlight и ddcutil setvcp для DDC, с доводкой;
//   * runner — Process + StdioCollector со страховкой от зависших потоков.
Singleton {
    id: root

    // ───────────── публичное состояние ─────────────

    // По одной записи на экран: { key, label, subtitle, method, device,
    // controllable, hint }. method: "backlight" | "ddc" | "".
    property var targets: []
    // Значения 0..1 по ключу цели. Карта пересобирается целиком: QML не
    // замечает изменение полей объекта.
    property var values: ({})
    // Максимум в родных единицах устройства (например 504 у backlight).
    property var maximums: ({})

    readonly property bool available: {
        for (let i = 0; i < root.targets.length; ++i) {
            if (root.targets[i].controllable)
                return true;
        }
        return false;
    }

    readonly property var primary: {
        for (let i = 0; i < root.targets.length; ++i) {
            if (root.targets[i].controllable)
                return root.targets[i];
        }
        return null;
    }

    readonly property string summary: {
        if (root.primary === null)
            return root.targets.length > 0 ? I18n.tr("quick.brightness.notAdjustable")
                                           : I18n.tr("quick.brightness.noDisplays");
        return Math.round(root.valueFor(root.primary.key) * 100) + "%";
    }

    function valueFor(key) {
        const value = root.values[key];
        return value === undefined ? 0 : value;
    }

    function targetByKey(key) {
        for (let i = 0; i < root.targets.length; ++i) {
            if (root.targets[i].key === key)
                return root.targets[i];
        }
        return null;
    }

    // ───────────── обнаружение ─────────────

    property var backlightNames: []
    // имя устройства → DRM-коннектор ("" — в пути его нет)
    property var backlightConnectors: ({})
    // [{ number, connector, label }]
    property var ddcDisplays: []
    // номер дисплея → поддерживает ли он VCP 10
    property var ddcSupported: ({})
    property bool ddcProbed: false
    property bool ddcProbing: false

    // Список backlight-устройств. Каталог читаем одним `ls`, а коннекторы —
    // одним `readlink` на все устройства сразу: порядок строк совпадает с
    // порядком аргументов.
    Process {
        id: listProc
        command: ["ls", "-1", "/sys/class/backlight"]
        running: true
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.applyBacklightList(listOut.text)
        }
        stderr: StdioCollector {}
    }

    function applyBacklightList(text) {
        const names = [];
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const name = lines[i].trim();
            if (name !== "")
                names.push(name);
        }
        root.backlightNames = names;
        root.rebuildTargets();
        if (names.length === 0) {
            // Backlight-устройств нет вовсе (десктоп с внешними мониторами):
            // яркость умеет менять только DDC/CI, поэтому спрашиваем сразу,
            // не дожидаясь открытия панели.
            if (root.hasExternalScreen())
                root.probeDdc();
            return;
        }
        const args = ["readlink", "-f"];
        for (let i = 0; i < names.length; ++i)
            args.push("/sys/class/backlight/" + names[i]);
        root.run(args, (code, out) => root.applyBacklightPaths(names, out));
    }

    function applyBacklightPaths(names, out) {
        const paths = (out || "").split("\n");
        const connectors = {};
        for (let i = 0; i < names.length; ++i)
            connectors[names[i]] = root.connectorFromPath((paths[i] || "").trim());
        root.backlightConnectors = connectors;
        root.rebuildTargets();
    }

    // .../drm/card1/card1-eDP-1/intel_backlight → eDP-1
    function connectorFromPath(path) {
        if (path === "")
            return "";
        const parts = path.split("/");
        const dir = parts.length >= 2 ? parts[parts.length - 2] : "";
        const match = /^card\d+-(.+)$/.exec(dir);
        return match !== null ? match[1] : "";
    }

    // ───────────── DDC/CI (внешние мониторы) ─────────────

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            id: ddcDetectOut
            onStreamFinished: root.finishDdcProbe(ddcDetectOut.text)
        }
        stderr: StdioCollector {}
    }

    // Если ddcutil не установлен, процесс не запустится и поток не закроется:
    // снимаем ожидание по таймеру, а не ждём вечно.
    Timer {
        id: ddcWatchdog
        interval: 5000
        onTriggered: {
            ddcDetect.running = false;
            root.finishDdcProbe("");
        }
    }

    function probeDdc() {
        if (root.ddcProbing)
            return;
        root.ddcProbing = true;
        ddcDetect.running = true;
        ddcWatchdog.restart();
    }

    // ddcutil detect — это несколько секунд и опрос всех шин I2C, поэтому
    // сам по себе он не запускается: ни на старте, ни на каждое перестроение
    // экранов, ни тем более на hot-reload конфига. Спрашиваем только когда
    // яркость действительно нечем менять — то есть для экрана без backlight.
    function needsDdcProbe() {
        if (root.ddcProbed || root.ddcProbing)
            return false;
        return root.hasScreenWithoutBacklight();
    }

    function hasScreenWithoutBacklight() {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; ++i) {
            const name = screens[i].name.toLowerCase();
            let covered = false;
            for (let b = 0; b < root.backlightNames.length; ++b) {
                if ((root.backlightConnectors[root.backlightNames[b]] || "").toLowerCase() === name) {
                    covered = true;
                    break;
                }
            }
            if (!covered)
                return true;
        }
        return false;
    }

    function hasExternalScreen() {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; ++i) {
            if (!root.looksInternal(screens[i].name))
                return true;
        }
        return false;
    }

    function finishDdcProbe(text) {
        if (!root.ddcProbing)
            return;
        root.ddcProbing = false;
        ddcWatchdog.stop();
        root.ddcProbed = true;
        root.ddcDisplays = root.parseDdcDetect(text);
        root.rebuildTargets();
        root.readDdc();
    }

    // Разбор `ddcutil detect --brief`:
    //   Display 1
    //      I2C bus:  /dev/i2c-4
    //      DRM connector:           card0-HDMI-A-1
    //      Monitor:                  DEL:Dell Inc.:DELL U2415
    // Разбор терпимый к отступам: важны только ключи, а не колонки.
    function parseDdcDetect(text) {
        const displays = [];
        let current = null;
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            const head = /^\s*Display\s+(\d+)\s*$/.exec(line);
            if (head !== null) {
                current = { number: parseInt(head[1], 10), connector: "", label: "" };
                displays.push(current);
                continue;
            }
            if (current === null)
                continue;
            const connector = /DRM\s+connector\s*:\s*(\S+)/i.exec(line);
            if (connector !== null) {
                current.connector = root.stripCardPrefix(connector[1]);
                continue;
            }
            const monitor = /^\s*Monitor\s*:\s*(.+)$/i.exec(line);
            if (monitor !== null) {
                // vendor:производитель:модель — для подписи годится модель
                const parts = monitor[1].trim().split(":");
                current.label = (parts[2] || parts[1] || parts[0] || "").trim();
            }
        }
        return displays;
    }

    function stripCardPrefix(connector) {
        const match = /^card\d+-(.+)$/.exec(connector);
        return match !== null ? match[1] : connector;
    }

    // `ddcutil getvcp 10 --brief` → "VCP 10 C 50 100"
    function parseDdcValue(text) {
        const match = /VCP\s+10\s+C\s+(\d+)\s+(\d+)/.exec(text || "");
        if (match === null)
            return null;
        return { value: parseInt(match[1], 10), max: parseInt(match[2], 10) };
    }

    // Чтение DDC — это тоже процесс и транзакция по I2C, поэтому на один
    // дисплей одновременно не больше одного getvcp: иначе при медленном
    // мониторе они копятся и оболочка встаёт.
    property var ddcReading: ({})

    function readDdc() {
        for (let i = 0; i < root.ddcDisplays.length; ++i) {
            const display = root.ddcDisplays[i];
            if (root.ddcSupported[display.number] === false)
                continue;
            const number = display.number;
            if (root.ddcReading[number])
                continue;
            root.ddcReading = root.mapWith(root.ddcReading, number, true);
            root.run(["ddcutil", "--display", "" + number, "getvcp", "10", "--brief"],
                     (code, out) => {
                         root.ddcReading = root.mapWithout(root.ddcReading, number);
                         root.applyDdcValue(number, code, out);
                     });
        }
    }

    function mapWithout(map, key) {
        const next = {};
        for (const existing in map) {
            if (existing !== "" + key)
                next[existing] = map[existing];
        }
        return next;
    }

    function applyDdcValue(number, code, out) {
        const parsed = root.parseDdcValue(out);
        if (code !== 0 || parsed === null) {
            // Монитор без DDC/CI или без VCP 10: больше не спрашиваем.
            root.markDdcUnsupported(number);
            return;
        }
        root.applyRawValue("ddc:" + number, parsed.value, parsed.max);
    }

    function markDdcUnsupported(number) {
        if (root.ddcSupported[number] === false)
            return;
        const next = {};
        for (const key in root.ddcSupported)
            next[key] = root.ddcSupported[key];
        next[number] = false;
        root.ddcSupported = next;
        root.rebuildTargets();
    }

    // ───────────── сборка целей ─────────────

    function rebuildTargets() {
        const screens = Quickshell.screens;
        const slots = [];
        const usedBacklights = {};
        const usedDisplays = {};

        for (let i = 0; i < screens.length; ++i) {
            const screen = screens[i];
            const name = screen.name;
            const lower = name.toLowerCase();
            let target = null;

            for (let b = 0; b < root.backlightNames.length; ++b) {
                const device = root.backlightNames[b];
                if (usedBacklights[device])
                    continue;
                if ((root.backlightConnectors[device] || "").toLowerCase() === lower) {
                    target = root.makeBacklightTarget(screen, device);
                    usedBacklights[device] = true;
                    break;
                }
            }

            if (target === null) {
                for (let d = 0; d < root.ddcDisplays.length; ++d) {
                    const display = root.ddcDisplays[d];
                    if (usedDisplays[display.number])
                        continue;
                    if ((display.connector || "").toLowerCase() === lower) {
                        target = root.makeDdcTarget(screen, display);
                        usedDisplays[display.number] = true;
                        break;
                    }
                }
            }

            slots.push(target);
        }

        // Запасное правило: backlight без коннектора (acpi_video0 и подобные)
        // достаётся внутренней панели, а если её нет — первому свободному
        // экрану. Так яркость работает и там, где sysfs не называет коннектор.
        for (let b = 0; b < root.backlightNames.length; ++b) {
            const device = root.backlightNames[b];
            if (usedBacklights[device])
                continue;
            let index = -1;
            for (let i = 0; i < screens.length; ++i) {
                if (slots[i] !== null)
                    continue;
                if (index < 0 || root.looksInternal(screens[i].name))
                    index = i;
                if (root.looksInternal(screens[i].name))
                    break;
            }
            if (index < 0)
                continue;
            slots[index] = root.makeBacklightTarget(screens[index], device);
            usedBacklights[device] = true;
        }

        // DDC-дисплеи без совпавшего коннектора — свободным внешним экранам.
        for (let d = 0; d < root.ddcDisplays.length; ++d) {
            const display = root.ddcDisplays[d];
            if (usedDisplays[display.number])
                continue;
            for (let i = 0; i < screens.length; ++i) {
                if (slots[i] !== null || root.looksInternal(screens[i].name))
                    continue;
                slots[i] = root.makeDdcTarget(screens[i], display);
                usedDisplays[display.number] = true;
                break;
            }
        }

        const result = [];
        for (let i = 0; i < screens.length; ++i)
            result.push(slots[i] !== null ? slots[i] : root.makePlainTarget(screens[i]));
        root.targets = result;
    }

    function looksInternal(name) {
        return /^(eDP|LVDS|DSI)/i.test(name);
    }

    function makeBacklightTarget(screen, device) {
        return {
            key: "backlight:" + device,
            label: screen.name,
            subtitle: screen.model !== "" ? screen.model
                                           : I18n.tr("quick.brightness.backlight"),
            method: "backlight",
            device: device,
            controllable: true,
            hint: ""
        };
    }

    function makeDdcTarget(screen, display) {
        const supported = root.ddcSupported[display.number] !== false;
        return {
            key: "ddc:" + display.number,
            label: screen.name,
            subtitle: display.label !== "" ? display.label
                                           : (screen.model !== "" ? screen.model : "DDC/CI"),
            method: "ddc",
            device: display.number,
            controllable: supported,
            hint: supported ? "" : I18n.tr("quick.brightness.ddcUnsupported")
        };
    }

    function makePlainTarget(screen) {
        let hint = I18n.tr("quick.brightness.noControl");
        if (!root.looksInternal(screen.name)) {
            if (!root.ddcProbed)
                hint = I18n.tr("quick.brightness.checking");
            else if (root.ddcDisplays.length === 0)
                hint = I18n.tr("quick.brightness.ddcUnavailable");
            else
                hint = I18n.tr("quick.brightness.monitorNoBrightness");
        }
        return {
            key: "screen:" + screen.name,
            label: screen.name,
            subtitle: screen.model || "",
            method: "",
            device: "",
            controllable: false,
            hint: hint
        };
    }

    // ───────────── чтение значений ─────────────

    Instantiator {
        id: brightnessViews
        model: root.backlightNames

        delegate: FileView {
            required property string modelData

            path: "/sys/class/backlight/" + modelData + "/brightness"
            watchChanges: true
            onLoadedChanged: if (loaded) root.scheduleBacklightRead()
            onFileChanged: {
                reload();
                root.scheduleBacklightRead();
            }
        }
    }

    Instantiator {
        id: maxViews
        model: root.backlightNames

        delegate: FileView {
            required property string modelData

            path: "/sys/class/backlight/" + modelData + "/max_brightness"
            onLoadedChanged: if (loaded) root.applyMaximum(modelData, parseInt(text(), 10))
        }
    }

    // FileView перечитывает файл асинхронно: сразу после события text() ещё
    // старый, поэтому значение забираем с небольшой задержкой.
    Timer {
        id: backlightSettle
        interval: 200
        onTriggered: root.readBacklights()
    }

    function scheduleBacklightRead() {
        backlightSettle.restart();
    }

    function readBacklights() {
        for (let i = 0; i < brightnessViews.count; ++i) {
            const view = brightnessViews.objectAt(i);
            const key = "backlight:" + view.modelData;
            root.applyRawValue(key, parseInt(view.text(), 10), root.maximums[key]);
        }
    }

    function applyMaximum(device, max) {
        if (!(max > 0))
            return;
        const next = {};
        for (const key in root.maximums)
            next[key] = root.maximums[key];
        next["backlight:" + device] = max;
        root.maximums = next;
        root.scheduleBacklightRead();
    }

    function applyRawValue(key, raw, max) {
        if (!(max > 0) || isNaN(raw))
            return;
        // Пока идёт наша запись, файл может отдать ещё старое значение —
        // иначе слайдер дёргался бы назад под пальцем.
        if (root.pendingBacklight[key] !== undefined || root.pendingDdc[key] !== undefined)
            return;
        root.storeValue(key, Math.max(0, Math.min(1, raw / max)));
    }

    function storeValue(key, value) {
        const next = {};
        for (const existing in root.values)
            next[existing] = root.values[existing];
        next[key] = value;
        root.values = next;
    }

    // ───────────── запись ─────────────
    //
    // Две очереди с разным темпом. Значение на экран всегда одно — последнее,
    // поэтому очередь не растёт, а слайдер успевает за пальцем: во время
    // перетаскивания пишем раз в throttle, а не один раз на отпускании.
    // logind — быстрый вызов D-Bus, ему хватает 100 мс; ddcutil — это
    // отдельный процесс и транзакция по I2C, чаще четырёх раз в секунду его
    // дёргать нельзя: и монитор не успевает, и оболочка начинает тормозить.

    property var pendingBacklight: ({})
    property var pendingDdc: ({})
    // Последнее ненулевое значение — чтобы toggle() возвращал яркость.
    property var lastNonZero: ({})

    Timer {
        id: backlightFlush
        interval: 100
        repeat: true
        onTriggered: {
            root.flushGroup("backlight");
            if (!root.hasPending("backlight"))
                backlightFlush.stop();
        }
    }

    Timer {
        id: ddcFlush
        interval: 250
        repeat: true
        onTriggered: {
            root.flushGroup("ddc");
            if (!root.hasPending("ddc")) {
                ddcFlush.stop();
                // Драг закончился: один раз сверяем фактическое значение.
                ddcReconcile.restart();
            }
        }
    }

    Timer {
        id: ddcReconcile
        interval: 1200
        onTriggered: root.readDdc()
    }

    function setValue(key, value) {
        const target = root.targetByKey(key);
        if (target === null || !target.controllable)
            return;
        const clamped = Math.max(0, Math.min(1, value));
        if (clamped > 0.001)
            root.rememberNonZero(key, clamped);
        root.storeValue(key, clamped);

        if (target.method === "backlight") {
            root.pendingBacklight = root.mapWith(root.pendingBacklight, key, clamped);
            if (!backlightFlush.running)
                backlightFlush.start();
        } else if (target.method === "ddc") {
            root.pendingDdc = root.mapWith(root.pendingDdc, key, clamped);
            if (!ddcFlush.running)
                ddcFlush.start();
            ddcReconcile.stop();
        }
    }

    // Кружок плитки: погасить и вернуть прежнюю яркость.
    function togglePrimary() {
        const target = root.primary;
        if (target === null)
            return;
        if (root.valueFor(target.key) > 0.001) {
            root.rememberNonZero(target.key, root.valueFor(target.key));
            root.setValue(target.key, 0);
        } else {
            const stored = root.lastNonZero[target.key];
            root.setValue(target.key, stored === undefined ? 0.5 : stored);
        }
    }

    function rememberNonZero(key, value) {
        root.lastNonZero = root.mapWith(root.lastNonZero, key, value);
    }

    function mapWith(map, key, value) {
        const next = {};
        for (const existing in map)
            next[existing] = map[existing];
        next[key] = value;
        return next;
    }

    function hasPending(group) {
        const queue = group === "ddc" ? root.pendingDdc : root.pendingBacklight;
        for (const key in queue)
            return true;
        return false;
    }

    function flushGroup(group) {
        const queue = group === "ddc" ? root.pendingDdc : root.pendingBacklight;
        if (group === "ddc")
            root.pendingDdc = ({});
        else
            root.pendingBacklight = ({});

        for (const key in queue) {
            const target = root.targetByKey(key);
            if (target === null)
                continue;
            const max = root.maximums[key] > 0 ? root.maximums[key] : 100;
            const raw = Math.max(0, Math.min(max, Math.round(queue[key] * max)));
            if (target.method === "backlight")
                root.writeLogind(target.device, raw);
            else if (target.method === "ddc")
                root.writeDdc(target.device, raw);
        }
    }

    function writeLogind(device, value) {
        root.run(["busctl", "call", "org.freedesktop.login1",
                  "/org/freedesktop/login1/session/auto",
                  "org.freedesktop.login1.Session", "SetBrightness",
                  "ssu", "backlight", device, "" + value],
                 (code, out, err) => {
                     if (code !== 0)
                         console.warn("Brightness: logind не принял значение:", (err || "").trim());
                     else
                         root.scheduleBacklightRead();
                 });
    }

    function writeDdc(number, value) {
        root.run(["ddcutil", "--display", "" + number, "setvcp", "10",
                  "" + value, "--noverify"],
                 (code, out, err) => {
                     if (code !== 0)
                         console.warn("Brightness: ddcutil setvcp:", (err || "").trim());
                 });
    }

    // ───────────── runner ─────────────

    Component {
        id: procComp

        Process {
            id: proc

            property var cb: null
            property bool exited: false
            property bool forced: false
            property int pendingStreams: 2
            property int code: -1

            stdout: StdioCollector {
                onStreamFinished: {
                    proc.pendingStreams--;
                    proc.maybeDone();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    proc.pendingStreams--;
                    proc.maybeDone();
                }
            }
            onExited: (exitCode, exitStatus) => {
                proc.code = exitCode;
                proc.exited = true;
                // Коллекторы могут закончить на следующем цикле событий.
                Qt.callLater(proc.forceDone);
                proc.maybeDone();
            }

            function forceDone() {
                proc.forced = true;
                proc.maybeDone();
            }

            function maybeDone() {
                if (!proc.exited || proc.cb === null)
                    return;
                if (!proc.forced && proc.pendingStreams > 0)
                    return;
                const callback = proc.cb;
                proc.cb = null;
                callback(proc.code, proc.stdout.text, proc.stderr.text);
                proc.destroy();
            }
        }
    }

    function run(args, cb) {
        const proc = procComp.createObject(root, { command: args, cb: cb });
        proc.running = true;
        return proc;
    }

    // ───────────── перечитывание ─────────────

    // Панель открыли — за время, пока её не было, яркость могли поменять
    // кнопками на клавиатуре или на мониторе. Тут же, если для какого-то
    // экрана backlight нет, спрашиваем DDC (один раз на набор экранов).
    Connections {
        target: UiState

        function onPanelChanged() {
            if (UiState.panel !== "brightness")
                return;
            for (let i = 0; i < brightnessViews.count; ++i)
                brightnessViews.objectAt(i).reload();
            root.scheduleBacklightRead();
            if (root.needsDdcProbe())
                root.probeDdc();
            else
                root.readDdc();
        }
    }

    // Подключили монитор: backlight-устройства не меняются, а DDC-дисплеи
    // могли появиться или исчезнуть. Сброс делаем без опроса: ddcutil
    // запустится только при следующем открытии панели (или сразу, если она
    // уже открыта).
    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.rebuildTargets();
            root.ddcDisplays = [];
            root.ddcSupported = ({});
            root.ddcProbed = false;
            if (UiState.panel === "brightness")
                screensDebounce.restart();
        }
    }

    Timer {
        id: screensDebounce
        interval: 1500
        onTriggered: {
            if (root.needsDdcProbe())
                root.probeDdc();
        }
    }

    Component.onCompleted: {
        root.rebuildTargets();
    }
}
