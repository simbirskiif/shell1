pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Реальный backend панели «Интернет» поверх NetworkManager.
//
// Источник истины — NM: сервис ничего не хранит на диске, профили, ключи и
// маршруты остаются за NM. Здесь только чтение состояния, аккуратный разбор
// terse-вывода nmcli и перевод действий пользователя в команды.
//
// Почему не только `nmcli`: в nmcli 1.58 пароль нельзя передать ни через
// stdin (`--ask` без TTY зацикливается на повторных запросах), ни позиционным
// аргументом (`password <psk>` больше не принимается — нужен `passwd-file`
// или `connection up`, а это лишний профиль-черновик на диске). Поэтому
// единственный путь с паролем — нативный модуль `Quickshell.Networking`:
// `WifiNetwork.connectWithPsk()` отдаёт секрет в NM через D-Bus, минуя argv,
// TTY и временные файлы (см. раздел 11.2 руководства).
//
// Слои:
//   * публичный API — там же, где был MockState (имена совместимы);
//   * действия — connectSaved/connectOpen/submitPassword/setupEnterprise/…;
//   * состояние — кэш сетей, профилей, устройства, connectingName, pendingNetwork;
//   * парсеры — splitTerse, mapSecurity, classifyError, syncModel;
//   * runner — run(args, cb, stdin) и очередь мутирующих команд;
//   * монитор — постоянный `nmcli monitor` → debounce → refresh().
//
// Правила, которые важно не потерять при правках:
//   1. requestWifi решает всё синхронно по кэшу; pendingNetwork выставляется
//      до любых асинхронных вызовов (фронт проверяет его сразу после клика).
//   2. Мутирующие команды идут по одной через очередь: scan не должен стартовать
//      раньше, чем radio реально включилось.
//   3. Пароль не попадает ни в argv, ни на диск.
//   4. Список сетей обновляется синхронизацией по ключу (ListModel), а не
//      присваиванием нового массива: иначе ListView пересоздаёт делегаты
//      и список мерцает.
Singleton {
    id: root

    // ───────────── публичный API ─────────────

    // Состояние Wi-Fi radio: программное и аппаратное.
    property bool wifiEnabled: false
    property bool wifiHardBlocked: false
    property bool wifiScanning: false
    // false, если nmcli не найден или NM не отвечает: панель показывает заглушку.
    property bool backendAvailable: true

    // Проводное соединение (одна строка в панели).
    property bool ethernetConnected: false
    property bool internetViaEthernet: false
    property string ethernetName: ""
    property string ethernetSpeed: ""
    // "", "connecting", "connected", "disconnected", "unavailable", "unmanaged"
    property string ethernetState: ""

    // Состояние подключения (общее для диалога и строк списка).
    property string pendingNetwork: ""     // сеть, для которой спрашиваем пароль
    property string connectingName: ""     // сеть, к которой идёт подключение
    property string connectError: ""       // "", auth, timeout, dhcp, notfound, other
    property string connectErrorText: ""   // сырой текст для лога и подсказки

    // "full", "portal", "limited", "none", "unknown"
    property string connectivity: "unknown"

    // Пароль живёт здесь только между вводом и вызовом submitPassword.
    // Свойство нужно фронту (поле ввода), после запуска подключения обнуляется.
    property string pendingPassword: ""

    // Скелет enterprise-профиля открыт в редакторе NM.
    readonly property bool editorRunning: editorProc.running

    readonly property string ethernetSummary: {
        if (!ethernetConnected)
            return "";
        if (internetViaEthernet)
            return ethernetSpeed !== "" ? ethernetSpeed : "Connected";
        return "Not active";
    }

    readonly property string internetSummary: {
        if (internetViaEthernet)
            return ethernetName;
        if (!wifiEnabled)
            return "Off";
        return connectedSsid !== "" ? connectedSsid : "Not connected";
    }

    // Имя активной Wi-Fi сети (для плитки и заголовка).
    property string connectedSsid: ""

    readonly property ListModel wifiNetworks: availableModel
    readonly property ListModel savedWifiNetworks: savedModel

    ListModel { id: availableModel }
    ListModel { id: savedModel }

    // ───────────── внутреннее состояние ─────────────

    // Список точек доступа: { name, strength, security, connected, bssid }
    property var scanned: []
    // Профили Wi-Fi: uuid -> { name, uuid, ssid }
    property var profiles: ({})
    // Кэш SSID профиля по uuid, чтобы не запускать процесс на каждый refresh.
    property var profileSsid: ({})
    // Множество uuid профилей Wi-Fi на момент попытки: по разнице вычисляем,
    // какой профиль создала неудачная попытка, чтобы его удалить.
    property var uuidsBeforeConnect: ({})

    property string wifiDev: ""
    // Интерфейс Wi-Fi уже был найден: пока radio выключено, NM не отдаёт
    // устройство, и это не значит, что адаптер пропал.
    property bool wifiDevKnown: false
    // Устройство Wi-Fi есть в текущем списке устройств NM: пока radio
    // выключено, его там нет.
    property bool wifiDevPresent: false
    property string wifiDevState: ""
    property string wifiDevConnection: ""

    property string wiredDev: ""
    property string wiredConnection: ""
    property string wiredState: ""

    // Очередь мутирующих команд: по одной за раз.
    property var cmdQueue: []
    property bool cmdBusy: false
    // Текущий процесс подключения (его можно прервать).
    property var activeConnectProc: null
    property bool connectCancelled: false
    // Поколение попытки: ответы устаревших процессов игнорируются.
    property int connectGeneration: 0

    // Сколько профилей SSID уже прочитано в этом refresh.
    property var ssidQueue: []
    property int ssidBusy: 0

    // nmcli отдаёт состояние и кодом, и текстом: "connected (externally)",
    // "100 (connected)", в `device show` — "GENERAL.STATE:100 (connected)".
    // Сравнивать надо по имени состояния, код зависит от версии NM.
    function parseDeviceState(field) {
        let text = field || "";
        const colon = text.lastIndexOf(":");
        if (colon >= 0)
            text = text.substring(colon + 1);
        const open = text.indexOf(" (");
        if (open >= 0)
            text = text.substring(0, open);
        return text.trim();
    }

    function wifiIconStrength(signal) {
        // nmcli отдаёт SIGNAL 0–100, PanelIcon ждёт 0–4.
        if (signal <= 0)
            return 0;
        return Math.max(1, Math.min(4, Math.round(signal / 25)));
    }

    // ───────────── runner ─────────────

    Component {
        id: procComp

        Process {
            id: proc

            property var cb: null
            property string input: ""
            property int code: -1
            property int pending: 2

            environment: ({ LC_ALL: "C" })
            stdinEnabled: proc.input !== ""

            stdout: StdioCollector {
                onStreamFinished: {
                    proc.pending--;
                    proc.done();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    proc.pending--;
                    proc.done();
                }
            }
            onStarted: if (proc.input !== "")
                proc.write(proc.input)
            onExited: (exitCode, exitStatus) => {
                proc.code = exitCode;
                proc.done();
            }

            function done() {
                if (proc.code === -1 || proc.pending > 0)
                    return;
                const callback = proc.cb;
                proc.cb = null;
                if (callback)
                    callback(proc.code, proc.stdout.text, proc.stderr.text);
                proc.destroy();
            }
        }
    }

    // Читающие команды можно запускать параллельно.
    function run(args, cb, input) {
        const proc = procComp.createObject(root, {
            command: args,
            cb: cb,
            input: input || ""
        });
        proc.running = true;
        return proc;
    }

    // ───────────── парсеры ─────────────

    // В terse-режиме nmcli экранирует ":" и "\" обратным слэшем, поэтому
    // line.split(":") не годится.
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; ++i) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length)
                cur += line[++i];
            else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function lines(text) {
        const out = [];
        const parts = (text || "").split("\n");
        for (let i = 0; i < parts.length; ++i) {
            const line = parts[i];
            if (line !== "")
                out.push(line);
        }
        return out;
    }

    function mapSecurity(s) {
        if (!s || s === "--")
            return "open";
        if (s.indexOf("802.1X") >= 0)
            return "enterprise";
        if (s === "OWE")
            return "open";
        return "psk";
    }

    function fmtSpeed(mbit) {
        if (mbit <= 0)
            return "";
        if (mbit >= 1000)
            return (mbit / 1000).toFixed(1).replace(/\.0$/, "") + " Gbit/s";
        return mbit + " Mbit/s";
    }

    function classifyError(err, security) {
        const text = err || "";
        if (/Secrets were required/i.test(text))
            return "auth";
        if (/supplicant/i.test(text))
            return security === "psk" ? "auth" : "other";
        if (/802\.1X|\bEAP\b|authentication/i.test(text))
            return "auth";
        if (/IP configuration|DHCP/i.test(text))
            return "dhcp";
        if (/No network with SSID|could not be found/i.test(text))
            return "notfound";
        if (/Timeout expired|timed out/i.test(text))
            return "timeout";
        return "other";
    }

    // Синхронизация ListModel по ключу: удалить исчезнувшие, обновить поля
    // существующих, вставить новые, переставить в нужном порядке. Модель
    // остаётся той же самой — делегаты не пересоздаются.
    function syncModel(model, items) {
        for (let i = model.count - 1; i >= 0; --i) {
            const current = model.get(i);
            let found = false;
            for (let j = 0; j < items.length; ++j) {
                if (items[j].name === current.name) {
                    found = true;
                    break;
                }
            }
            if (!found)
                model.remove(i);
        }

        for (let idx = 0; idx < items.length; ++idx) {
            const item = items[idx];
            let at = -1;
            let stale = false;
            for (let j = 0; j < model.count; ++j) {
                if (model.get(j).name === item.name) {
                    at = j;
                    stale = model.get(j).uuid !== item.uuid
                            || model.get(j).security !== item.security;
                    break;
                }
            }
            if (at < 0) {
                model.insert(Math.min(idx, model.count), item);
            } else if (stale) {
                model.remove(at);
                model.insert(Math.min(idx, model.count), item);
            } else {
                model.set(at, item);
                if (at !== idx)
                    model.move(at, idx, 1);
            }
        }
    }

    function findNetwork(name) {
        const models = [savedModel, availableModel];
        for (let m = 0; m < models.length; ++m) {
            const model = models[m];
            for (let i = 0; i < model.count; ++i) {
                if (model.get(i).name === name)
                    return model.get(i);
            }
        }
        return null;
    }

    function profileForSsid(ssid) {
        let best = null;
        for (const uuid in root.profiles) {
            const profile = root.profiles[uuid];
            if (profile.ssid !== ssid)
                continue;
            if (best === null || profile.name < best.name)
                best = profile;
        }
        return best;
    }

    // ───────────── refresh ─────────────

    Timer {
        id: refreshDebounce
        interval: 300
        onTriggered: root.refresh()
    }

    function scheduleRefresh() {
        refreshDebounce.restart();
    }

    function refresh() {
        const bag = { parts: 0, got: 0, cb: (key, code, out, err) => applyPart(bag, key, code, out, err) };
        bag.parts = 5;
        ask("radio", ["nmcli", "-t", "-f", "WIFI,WIFI-HW", "radio"], bag.cb);
        ask("devices", ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], bag.cb);
        ask("profiles", ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show"], bag.cb);
        ask("connectivity", ["nmcli", "-t", "networking", "connectivity"], bag.cb);
        ask("route", ["ip", "-o", "route", "show", "default"], bag.cb);
        if (root.wifiDev !== "" || !root.wifiDevKnown)
            bag.parts++;
        if (root.wifiDev !== "" && root.wifiEnabled) {
            bag.parts++;
            ask("apstate", ["nmcli", "-t", "-f", "GENERAL.STATE,GENERAL.CONNECTION",
                            "device", "show", root.wifiDev], bag.cb);
        }
        if (root.wifiDev !== "" && root.wifiEnabled && !root.wifiScanning) {
            bag.parts++;
            const device = root.wifiDev;
            run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID",
                 "device", "wifi", "list", "ifname", device, "--rescan", "no"],
                (code, out, err) => {
                    bag.cb("wifi", code, out, err);
                    // Устройство уже было известно — отложенный скан можно
                    // запускать, не дожидаясь следующего refresh.
                    root.onWifiReady();
                });
        }
    }

    function ask(key, args, cb) {
        run(args, (code, out, err) => cb(key, code, out, err));
    }

    function applyPart(bag, key, code, out, err) {
        applyResult(key, code, out, err);
        bag.got++;
        if (bag.got >= bag.parts)
            finishRefresh();
    }

    function applyResult(key, code, out, err) {
        if (key === "radio") {
            if (code !== 0) {
                backendAvailable = false;
                wifiEnabled = false;
                return;
            }
            backendAvailable = true;
            const cols = splitTerse(lines(out)[0] || "");
            wifiEnabled = (cols[0] || "") === "enabled";
            wifiHardBlocked = (cols[1] || "") !== "enabled";
        } else if (key === "devices") {
            applyDevices(out);
        } else if (key === "profiles") {
            applyProfiles(out);
        } else if (key === "connectivity") {
            const value = (out || "").trim();
            connectivity = value !== "" ? value : "unknown";
        } else if (key === "route") {
            applyRoute(out);
        } else if (key === "wifi") {
            scanned = parseWifiList(out);
        } else if (key === "apstate") {
            const cols = splitTerse(lines(out)[0] || "");
            wifiDevState = parseDeviceState(cols[0]);
            wifiDevConnection = cols[1] || "";
        }
    }

    function applyDevices(out) {
        let wifi = "";
        const physical = [];
        wiredRows = [];
        const rows = lines(out);
        for (let i = 0; i < rows.length; ++i) {
            const cols = splitTerse(rows[i]);
            const device = cols[0];
            const type = cols[1];
            const state = cols[2] || "";
            const connection = cols[3] || "";
            if (type === "wifi" && device.indexOf("p2p-") !== 0) {
                // Управляемое устройство предпочтительнее unmanaged.
                if (wifi === "" || state !== "unmanaged")
                    wifi = device;
            } else if (type === "ethernet") {
                wiredRows.push({ device: device, state: parseDeviceState(state), connection: connection });
                physical.push(device);
            }
        }
        if (wifi !== "") {
            wifiDev = wifi;
            wifiDevKnown = true;
        } else if (!wifiDevKnown) {
            wifiDev = "";
        }
        wifiDevPresent = wifi !== "";
        checkPhysical(physical);
    }

    property var wiredRows: []
    property var physicalWired: []

    // Проводной `ethernet` в nmcli бывает и виртуальным (USB-tethering — это
    // тоже ethernet, и его показывать надо, а мосты — нет). Признак
    // физического интерфейса — наличие /sys/class/net/<dev>/device.
    function checkPhysical(devices) {
        if (devices.length === 0) {
            physicalWired = [];
            pickWired();
            return;
        }
        const args = ["sh", "-c",
                      'for d in "$@"; do [ -e "/sys/class/net/$d/device" ] && echo "$d"; done',
                      "sh"].concat(devices);
        run(args, (code, out) => {
            physicalWired = code === 0 ? lines(out) : devices;
            pickWired();
            scheduleModelUpdate();
        });
    }

    // Фронт рисует одну строку, поэтому выбираем «главное» проводное
    // устройство: подключённое, иначе первое физическое.
    function pickWired() {
        let chosen = null;
        for (let i = 0; i < physicalWired.length; ++i) {
            const device = physicalWired[i];
            for (let j = 0; j < wiredRows.length; ++j) {
                const row = wiredRows[j];
                if (row.device !== device)
                    continue;
                if (row.state === "connected") {
                    chosen = row;
                    break;
                }
                if (chosen === null)
                    chosen = row;
            }
            if (chosen !== null && chosen.state === "connected")
                break;
        }
        wiredDev = chosen === null ? "" : chosen.device;
        wiredState = chosen === null ? "" : chosen.state;
        wiredConnection = chosen === null ? "" : chosen.connection;
        syncRoute();
    }

    function applyProfiles(out) {
        const next = ({});
        const rows = lines(out);
        for (let i = 0; i < rows.length; ++i) {
            const cols = splitTerse(rows[i]);
            if (cols[2] !== "802-11-wireless")
                continue;
            const uuid = cols[1];
            next[uuid] = {
                name: cols[0],
                uuid: uuid,
                ssid: profileSsid[uuid] !== undefined ? profileSsid[uuid] : ""
            };
        }
        profiles = next;
        fetchMissingSsids();
    }

    // SSID профиля не обязан совпадать с именем профиля, а спрашивать его
    // на каждый refresh — это N процессов. Поэтому кэшируем по uuid и
    // добираем только те, что ещё не читали.
    function fetchMissingSsids() {
        for (const uuid in root.profiles) {
            if (root.profileSsid[uuid] !== undefined)
                continue;
            if (root.ssidQueue.indexOf(uuid) >= 0)
                continue;
            root.ssidQueue.push(uuid);
        }
        pumpSsids();
    }

    function pumpSsids() {
        while (root.ssidBusy < 3 && root.ssidQueue.length > 0) {
            const uuid = root.ssidQueue.shift();
            root.ssidBusy++;
            run(["nmcli", "-t", "-f", "802-11-wireless.ssid", "connection", "show", "uuid", uuid],
                (code, out) => {
                    root.ssidBusy--;
                    if (code === 0) {
                        const cols = splitTerse(lines(out)[0] || "");
                        const ssid = cols.length > 1 ? cols[1] : cols[0];
                        const cache = root.profileSsid;
                        cache[uuid] = ssid || "";
                        root.profileSsid = cache;
                        const current = root.profiles;
                        if (current[uuid] !== undefined) {
                            current[uuid].ssid = cache[uuid];
                            root.profiles = current;
                        }
                        root.scheduleModelUpdate();
                    }
                    root.pumpSsids();
                });
        }
    }

    Timer {
        id: modelUpdateDebounce
        interval: 200
        onTriggered: root.updateModels()
    }

    function scheduleModelUpdate() {
        modelUpdateDebounce.restart();
    }

    property string defaultRouteDev: ""

    function applyRoute(out) {
        const rows = lines(out);
        let best = null;
        let bestMetric = 1e9;
        for (let i = 0; i < rows.length; ++i) {
            const cols = rows[i].split(/\s+/);
            let dev = "";
            let metric = 0;
            for (let j = 0; j < cols.length; ++j) {
                if (cols[j] === "dev")
                    dev = cols[j + 1] || "";
                else if (cols[j] === "metric")
                    metric = parseInt(cols[j + 1] || "0", 10);
            }
            if (dev !== "" && metric < bestMetric) {
                bestMetric = metric;
                best = dev;
            }
        }
        defaultRouteDev = best === null ? "" : best;
        syncRoute();
    }

    // Интернет идёт через провод, если минимальная метрика маршрута по
    // умолчанию принадлежит проводному устройству. NM даёт Ethernet ~100,
    // Wi-Fi ~600, поэтому при обоих побеждает кабель.
    function syncRoute() {
        const viaWired = defaultRouteDev !== "" && wiredDev !== ""
                && defaultRouteDev === wiredDev;
        internetViaEthernet = viaWired;
        if (viaWired)
            readSpeed(wiredDev);
        else
            ethernetSpeed = "";
    }

    function readSpeed(device) {
        run(["cat", "/sys/class/net/" + device + "/speed"], (code, out) => {
            if (wiredDev !== device)
                return;
            const mbit = code === 0 ? parseInt((out || "").trim(), 10) : 0;
            ethernetSpeed = isNaN(mbit) ? "" : fmtSpeed(mbit);
        });
    }

    function finishRefresh() {
        // Проводное состояние и имя собираются из уже разобранных частей.
        const connected = wiredDev !== "" && wiredState === "connected";
        ethernetConnected = connected;
        ethernetState = wiredState;
        ethernetName = wiredConnection !== "" ? wiredConnection : wiredDev;
        if (!connected)
            ethernetSpeed = "";

        // Активная Wi-Fi сеть: имя профиля активного соединения на Wi-Fi
        // устройстве, иначе — строка с IN-USE из списка точек.
        let ssid = "";
        if (wifiDevConnection !== "") {
            for (const uuid in root.profiles) {
                if (root.profiles[uuid].name === wifiDevConnection
                        || root.profiles[uuid].ssid === wifiDevConnection) {
                    ssid = root.profiles[uuid].ssid !== "" ? root.profiles[uuid].ssid
                                                           : root.profiles[uuid].name;
                    break;
                }
            }
            // Профиль мог ещё не попасть в кэш (первый refresh): имя
            // подключения в NM — это и есть SSID у сетей, созданных
            // `device wifi connect`.
            if (ssid === "")
                ssid = wifiDevConnection;
        }
        if (ssid === "") {
            for (let i = 0; i < scanned.length; ++i) {
                if (scanned[i].connected) {
                    ssid = scanned[i].name;
                    break;
                }
            }
        }
        connectedSsid = ssid;
        updateModels();
        onWifiReady();
    }

    // ───────────── разбор и раскладка списка сетей ─────────────

    function parseWifiList(text) {
        const groups = [];
        const index = ({});
        const rows = lines(text);
        for (let i = 0; i < rows.length; ++i) {
            const cols = splitTerse(rows[i]);
            const inUse = cols[0] === "*";
            const ssid = cols[1] || "";
            const signal = parseInt(cols[2] || "0", 10);
            const security = mapSecurity(cols[3] || "");
            const bssid = cols[4] || "";
            if (ssid === "")
                continue;   // скрытые сети в список не добавляем
            if (index[ssid] === undefined) {
                index[ssid] = groups.length;
                groups.push({
                    name: ssid,
                    strengthRaw: isNaN(signal) ? 0 : signal,
                    security: security,
                    connected: inUse,
                    bssid: bssid
                });
                continue;
            }
            const group = groups[index[ssid]];
            if (!isNaN(signal) && signal > group.strengthRaw)
                group.strengthRaw = signal;
            if (inUse) {
                group.connected = true;
                group.bssid = bssid;
            }
            // «Самый сильный» вариант безопасности в группе: enterprise важнее
            // psk, psk важнее открытой.
            if (security === "enterprise")
                group.security = "enterprise";
            else if (security === "psk" && group.security === "open")
                group.security = "psk";
        }
        return groups;
    }

    function applyWifiList(text) {
        scanned = parseWifiList(text);
        updateModels();
    }

    function updateModels() {
        // Строки, добавляемые вручную для проверки анимаций списка, живут
        // отдельно от сканирования: скан их не стирает.
        const aps = demoNetworks.concat(scanned);
        const saved = [];
        const available = [];
        for (let i = 0; i < aps.length; ++i) {
            const ap = aps[i];
            const profile = profileForSsid(ap.name);
            const item = {
                name: ap.name,
                strength: wifiIconStrength(ap.strengthRaw),
                security: ap.security,
                saved: profile !== null,
                connected: ap.connected,
                connecting: connectingSsid === ap.name,
                uuid: profile !== null ? profile.uuid : "",
                bssid: ap.bssid
            };
            if (profile !== null)
                saved.push(item);
            else
                available.push(item);
        }
        // Подключённая сеть — первой, затем по убыванию сигнала, при равенстве
        // по имени. Пересортировка идёт только при смене состава/состояния:
        // сигнал колеблется, и список не должен прыгать под курсором.
        const order = (a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.strength !== b.strength)
                return b.strength - a.strength;
            return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
        };
        saved.sort(order);
        available.sort(order);
        syncModel(savedModel, saved);
        syncModel(availableModel, available);
    }

    // ───────────── поиск сетей ─────────────
    //
    // Порядок: rescan (быстрый, не ждём) → пауза, чтобы NM собрал точки →
    // чтение кэша `--rescan no` (мгновенное). Индикатор держится всё время
    // скана и минимум ~700 мс, иначе он мигал бы на быстрых ответах.
    //
    // Если устройство Wi-Fi ещё не готово (сразу после `radio wifi on` NM
    // на несколько секунд отдаёт его как unavailable), скан откладывается в
    // scanPending, а индикатор включается сразу: экран не должен выглядеть
    // пустым и «мёртвым».

    Timer {
        id: scanGuard
        interval: 15000
        onTriggered: {
            // Устройство так и не появилось: снимаем индикатор, но запрос
            // скана не теряем — он выполнится при появлении устройства.
            root.stopScanTimers();
            root.wifiScanning = false;
        }
    }

    // Минимальная длительность индикатора.
    Timer {
        id: scanMin
        interval: 700
        onTriggered: {
            root.scanMinElapsed = true;
            root.tryFinishScan();
        }
    }

    // Пауза между rescan и чтением списка: даём NM собрать точки доступа.
    Timer {
        id: scanRead
        interval: 2200
        onTriggered: root.readWifiList()
    }

    property bool scanPending: false
    property bool scanMinElapsed: false
    property bool scanReadDone: false
    // Поколение сканов: ответы устаревших процессов игнорируются.
    property int scanGeneration: 0

    function stopScanTimers() {
        scanGuard.stop();
        scanMin.stop();
        scanRead.stop();
    }

    function scanWifi() {
        if (!wifiEnabled || !backendAvailable)
            return;
        if (wifiScanning)
            return;

        // Индикатор включаем сразу, ещё до готовности устройства.
        wifiScanning = true;
        scanPending = false;
        scanMinElapsed = false;
        scanReadDone = false;
        scanMin.restart();
        scanGuard.restart();

        if (wifiDev === "" || !wifiDevPresent || wifiDevState === "unavailable"
                || wifiDevState === "unmanaged") {
            scanPending = true;
            return;
        }
        beginScan(wifiDev);
    }

    function beginScan(device) {
        // Свежий rescan запускаем и не ждём его: nmcli при этом ещё и
        // троттлится, а список всё равно читаем из кэша NM.
        ++scanGeneration;
        run(["nmcli", "device", "wifi", "rescan", "ifname", device], (code, out, err) => {
            if (code !== 0 && (err || "").indexOf("not allowed") < 0)
                root.log("rescan: " + (err || "").trim());
        });
        scanReadDone = false;
        scanRead.restart();
    }

    function readWifiList() {
        const device = wifiDev;
        if (device === "")
            return;
        const generation = scanGeneration;
        run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID",
             "device", "wifi", "list", "ifname", device, "--rescan", "no"],
            (code, out, err) => {
                if (generation !== root.scanGeneration)
                    return;     // скан отменён или заменён новым
                if (code !== 0)
                    root.log("wifi list: " + (err || "").trim());
                applyWifiList(out);
                scanGuard.stop();
                scanReadDone = true;
                tryFinishScan();
                scheduleRefresh();
            });
    }

    // Индикатор снимается, когда список прочитан и прошла минимальная пауза.
    function tryFinishScan() {
        if (!scanReadDone || !scanMinElapsed)
            return;
        scanReadDone = false;
        wifiScanning = false;
    }

    // Устройство Wi-Fi появилось в списке NM и готово: доводим отложенный скан.
    function onWifiReady() {
        if (!scanPending || wifiDev === "")
            return;
        if (!wifiDevPresent || wifiDevState === "" || wifiDevState === "unavailable"
                || wifiDevState === "unmanaged")
            return;
        scanPending = false;
        beginScan(wifiDev);
    }

    // ───────────── включатель Wi-Fi ─────────────

    function toggleWifi() {
        if (wifiHardBlocked || !backendAvailable)
            return;
        setWifiEnabled(!wifiEnabled);
    }

    // Явное включение/выключение (кнопка «Turn on» и внешние команды):
    // toggleWifi() читает wifiEnabled, а он мог быть выставлен оптимистично
    // и ещё не подтверждён NM — тогда переключатель сработает не в ту сторону.
    function setWifiEnabled(target) {
        if (wifiHardBlocked || !backendAvailable)
            return;
        wifiEnabled = target;   // оптимистично, подтвердится в refresh()

        if (!target) {
            cancelActiveConnect();
            pskTimeout.stop();
            pendingPasswordCache = "";
            pendingNetwork = "";
            pendingPassword = "";
            connectError = "";
            connectErrorText = "";
            connectingName = "";
            expectedDisconnect = true;
            scanGeneration++;       // ответы текущего скана больше не нужны
            stopScanTimers();
            scanPending = false;
            scanReadDone = false;
            scanMinElapsed = false;
            wifiScanning = false;
            wifiDevPresent = false;
            scanned = [];
            savedModel.clear();
            availableModel.clear();
        } else {
            // Скан запустится сам, как только refresh подтвердит radio и
            // устройство: очередь гарантирует порядок radio on → скан.
            // Индикатор появится в тот же момент — пустого экрана без
            // признаков жизни не будет.
            if (!wifiScanning)
                scanPending = true;
        }
        enqueue(["nmcli", "radio", "wifi", target ? "on" : "off"], () => scheduleRefresh());
    }

    // ───────────── клик по сети ─────────────

    function requestWifi(name) {
        const network = findNetwork(name);
        if (network === null)
            return;

        if (network.connected) {
            disconnectWifi();
            return;
        }
        if (connectingName === name)
            return;             // повторный клик по подключающейся строке
        if (connectingName !== "")
            cancelActiveConnect();

        connectError = "";
        connectErrorText = "";

        // Enterprise-сети всегда уходят в редактор профиля: диалог пароля
        // умеет только PSK, а сохранённый профиль 802.1X может существовать
        // (тогда connectSaved попробует его с сохранёнными секретами).
        if (network.security === "enterprise" && !network.saved) {
            setupEnterprise(network);
            return;
        }
        if (network.saved)
            connectSaved(network);
        else if (network.security === "open")
            connectOpen(network);
        else if (network.security === "psk")
            pendingNetwork = name;      // синхронно, до любых процессов
    }

    function connectSaved(network) {
        const generation = ++connectGeneration;
        connectCancelled = false;
        connectingName = network.name;
        activeConnectProc = run(["nmcli", "-w", "30", "connection", "up",
                                 "uuid", network.uuid, "ifname", wifiDev],
            (code, out, err) => onConnectDone(generation, network, code, err, false));
    }

    function connectOpen(network) {
        const generation = ++connectGeneration;
        connectCancelled = false;
        connectingName = network.name;
        rememberProfiles();
        cleanupSsid = network.name;
        activeConnectProc = run(["nmcli", "-w", "30", "device", "wifi", "connect",
                                 network.name, "ifname", wifiDev],
            (code, out, err) => onConnectDone(generation, network, code, err, true));
    }

    // Пароль передаём нативному модулю: секрет уходит в NM по D-Bus, не
    // попадая ни в argv, ни в stdin, ни во временный файл. У сети с готовым
    // профилем (пароль на роутере сменили) профиль пересоздаётся: иначе NM
    // снова подставит старый сохранённый ключ. Минус — теряются нестандартные
    // настройки профиля (раздел 11.3 руководства).
    function submitPassword(password) {
        const name = pendingNetwork;
        const network = findNetwork(name);
        if (network === null || password === "")
            return;
        // WPA-PSK: 8–63 символа либо ровно 64 hex; иначе nmcli/NM ответит
        // невнятной ошибкой — проверяем на клиенте (раздел 11.1).
        if (!validPsk(password)) {
            connectError = "auth";
            connectErrorText = "password length is invalid";
            return;
        }
        pendingPassword = "";
        pendingPasswordCache = password;
        cleanupSsid = name;

        const generation = ++connectGeneration;
        connectCancelled = false;
        connectError = "";
        connectErrorText = "";
        connectingName = name;
        rememberProfiles();

        const start = () => {
            if (connectCancelled || generation !== connectGeneration) {
                pendingPasswordCache = "";
                return;
            }
            if (!connectPsk(network)) {
                pendingPasswordCache = "";
                // Сеть пропала из эфира (или её ещё нет в нативном списке):
                // профиль создавать нечем, показываем ошибку тостом.
                connectErrorText = "Wi-Fi network is not available";
                finishFailed(network, "notfound");
            }
        };

        if (network.saved && network.uuid !== "") {
            enqueue(["nmcli", "connection", "delete", "uuid", network.uuid], (code, out, err) => {
                if (code !== 0)
                    log("delete stale profile: " + (err || "").trim());
                start();
            });
        } else {
            start();
        }
    }

    // ───────────── подключение с паролем (нативный модуль) ─────────────

    // WPA-PSK — 8–63 символа либо ровно 64 hex-символа.
    function validPsk(password) {
        if (password.length >= 8 && password.length <= 63)
            return true;
        return password.length === 64 && /^[0-9a-fA-F]+$/.test(password);
    }

    property WifiNetwork pskTarget: null

    function wifiDevice() {
        // Первое Wi-Fi устройство: у нас оно же и единственное (раздел 4.5).
        for (let i = 0; i < Networking.devices.values.length; ++i) {
            const device = Networking.devices.values[i];
            if (device.type === DeviceType.Wifi)
                return device;
        }
        return null;
    }

    function pskNetwork(name) {
        const device = wifiDevice();
        if (device === null)
            return null;
        for (let i = 0; i < device.networks.values.length; ++i) {
            const network = device.networks.values[i];
            if (network.name === name)
                return network;
        }
        return null;
    }

    function isPskSecurity(security) {
        return security === WifiSecurityType.WpaPsk
                || security === WifiSecurityType.Wpa2Psk
                || security === WifiSecurityType.Sae;
    }

    function connectPsk(network) {
        const target = pskNetwork(network.name);
        if (target === null || !isPskSecurity(target.security)) {
            log("psk target is not available: " + network.name);
            return false;
        }
        pskTarget = target;
        target.connectWithPsk(pendingPasswordCache);
        pskTimeout.restart();
        return true;
    }

    // Нативный модуль видит только те сети, которые нашёл его собственный
    // сканер, а состояние берём то, где есть причина сбоя. Держим оба
    // источника согласованными: нативный сканер включаем, пока открыта
    // панель и включено radio.
    function syncNativeScanner() {
        const device = wifiDevice();
        if (device !== null)
            device.scannerEnabled = panelOpen && wifiEnabled;
    }

    onWifiEnabledChanged: syncNativeScanner()

    // Пароль для нативного вызова: submitPassword() кладёт его сюда и сразу
    // забывает входное значение, чтобы оно не жило в свойствах дольше нужного.
    property string pendingPasswordCache: ""

    // Реакция NM на попытку с паролем. Модуль отдаёт причину обобщённо
    // (NoSecrets — и для неверного пароля, и для отклонённого секрета),
    // поэтому «неверный пароль» — эвристика из раздела 12.1.
    Connections {
        target: root.pskTarget

        function onConnectionFailed(reason) {
            root.onPskFailed(reason);
        }

        function onConnectedChanged() {
            if (root.pskTarget !== null && root.pskTarget.connected)
                root.onPskSucceeded();
        }

        function onStateChanged() {
            if (root.pskTarget === null)
                return;
            if (root.pskTarget.state === ConnectionState.Connected)
                root.onPskSucceeded();
            else if (root.pskTarget.state === ConnectionState.Disconnected
                     && root.connectingName !== "")
                root.onPskFailed(ConnectionFailReason.Unknown);
        }
    }

    // Ответ на попытку приходит либо из NM (сигнал connectionFailed /
    // смена состояния), либо по таймауту.
    function onPskFailed(reason) {
        pskTimeout.stop();
        if (connectCancelled)
            return;
        const network = findNetwork(connectingName);
        const security = network === null ? "psk" : network.security;
        const kind = mapFailReason(reason, security);
        connectErrorText = "NM: " + ConnectionFailReason.toString(reason);
        log("psk connect failed: " + connectErrorText);
        finishFailed(network, kind);
    }

    function onPskSucceeded() {
        pskTimeout.stop();
        if (connectCancelled)
            return;
        const network = findNetwork(connectingName);
        // Запоминаем профиль, который NM создал/использовал для этой сети:
        // по нему можно деактивировать подключение при отмене.
        if (network !== null) {
            const profile = profileForSsid(network.name);
            pendingUuid = profile !== null ? profile.uuid : "";
        }
        onConnectDone(connectGeneration, network, 0, "", false);
    }

    // uuid активирующегося профиля: нужен, чтобы «отмена» действительно
    // прервала уже начавшуюся в NM активацию.
    property string pendingUuid: ""

    function mapFailReason(reason, security) {
        if (reason === ConnectionFailReason.NoSecrets)
            return security === "psk" ? "auth" : "other";
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "timeout";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "notfound";
        if (reason === ConnectionFailReason.WifiClientFailed
                || reason === ConnectionFailReason.WifiClientDisconnected)
            return security === "psk" ? "auth" : "other";
        return "other";
    }

    Timer {
        id: pskTimeout
        interval: 40000
        onTriggered: root.onPskTimeout()
    }

    function onPskTimeout() {
        if (connectingName === "")
            return;
        const network = findNetwork(connectingName);
        connectErrorText = "NM: connection attempt timed out";
        finishFailed(network, "timeout");
    }

    // Общая обработка неудачи: снять connecting, решить судьбу диалога
    // и уведомить пользователя.
    function finishFailed(network, kind) {
        // Попытка уже завершилась (например, пришли и connectionFailed,
        // и смена состояния): второй раз ничего не делаем.
        if (connectingName === "")
            return;
        const name = network !== null ? network.name : connectingName;
        const security = network !== null ? network.security : "psk";
        connectingName = "";
        pendingPasswordCache = "";
        pendingUuid = "";
        cleanupNewProfiles();
        if (kind === "auth" && security === "psk") {
            connectError = "auth";
            pendingNetwork = name;
        } else {
            connectError = kind;
            pendingNetwork = "";
            pendingPassword = "";
            notifyError(shortError(kind));
        }
        scheduleRefresh();
    }

    function cancelPending() {
        connectGeneration++;
        connectCancelled = true;
        cancelActiveConnect();
        pskTimeout.stop();
        // Уже начавшуюся активацию в NM тоже надо прервать: у нативной
        // попытки нет процесса, который можно убить.
        if (pendingUuid !== "")
            enqueue(["nmcli", "connection", "down", "uuid", pendingUuid], () => scheduleRefresh());
        pendingUuid = "";
        pendingPassword = "";
        pendingPasswordCache = "";
        pendingNetwork = "";
        connectError = "";
        connectErrorText = "";
        connectingName = "";
        cleanupNewProfiles();
    }

    function onConnectDone(generation, network, code, err, createdProfile) {
        activeConnectProc = null;
        if (generation !== connectGeneration || connectCancelled)
            return;             // попытку отменили или заменили новой

        connectingName = "";
        if (code === 0) {
            pendingNetwork = "";
            pendingPassword = "";
            pendingPasswordCache = "";
            pendingUuid = "";
            cleanupSsid = "";
            connectError = "";
            connectErrorText = "";
            if (wifiDev !== "")
                readDeviceState();
            checkConnectivity();
            scheduleRefresh();
            return;
        }

        connectErrorText = err;
        if (createdProfile)
            cleanupNewProfiles();
        finishFailed(network, classifyError(err, network.security));
    }

    function shortError(kind) {
        if (kind === "timeout")
            return "Connection timed out";
        if (kind === "dhcp")
            return "Connected, but no IP address";
        if (kind === "notfound")
            return "Network is out of range";
        if (kind === "auth")
            return "Authentication failed";
        return "Could not connect";
    }

    function cancelActiveConnect() {
        connectCancelled = true;
        if (activeConnectProc !== null) {
            activeConnectProc.cb = null;
            activeConnectProc.running = false;
            activeConnectProc = null;
        }
    }

    function rememberProfiles() {
        const snapshot = ({});
        for (const uuid in root.profiles)
            snapshot[uuid] = true;
        uuidsBeforeConnect = snapshot;
    }

    // Профиль, созданный неудачной попыткой, надо удалить: иначе «битая»
    // сеть окажется в «Saved» и NM будет бесконечно пробовать её автоподключить.
    // Нативный модуль создаёт профиль сам, поэтому дополнительно убираем
    // профили с этим SSID, которых не было до попытки.
    function cleanupNewProfiles() {
        const before = uuidsBeforeConnect;
        const ssid = cleanupSsid;
        if (ssid === "")
            return;         // не знаем, какую сеть убирать: не рискуем
        run(["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"], (code, out) => {
            if (code !== 0)
                return;
            const rows = lines(out);
            for (let i = 0; i < rows.length; ++i) {
                const cols = splitTerse(rows[i]);
                const name = cols[0];
                const uuid = cols[1];
                if (cols[2] !== "802-11-wireless")
                    continue;
                if (before[uuid] === true)
                    continue;
                if (name !== ssid && root.profileSsid[uuid] !== ssid)
                    continue;
                enqueue(["nmcli", "connection", "delete", "uuid", uuid], () => scheduleRefresh());
            }
        });
    }

    // SSID попытки, профили которого надо убрать после неудачи.
    property string cleanupSsid: ""

    // Строка должна «крутиться», если подключаемся мы сами или если NM
    // активирует профиль по своей инициативе (автоподключение после сна,
    // роуминг). Состояния устройства: prepare/config/need_auth/ip-config/
    // ip-check/secondaries (раздел 17.3).
    function deviceActivating() {
        return wifiDevState === "prepare" || wifiDevState === "config"
                || wifiDevState === "need_auth" || wifiDevState === "ip-config"
                || wifiDevState === "ip-check" || wifiDevState === "secondaries";
    }

    // Сеть, которую NM активирует сам: имя активного профиля устройства,
    // приведённое к SSID.
    readonly property string activatingSsid: {
        if (!deviceActivating() || wifiDevConnection === "")
            return "";
        for (const uuid in root.profiles) {
            if (root.profiles[uuid].name === wifiDevConnection)
                return root.profiles[uuid].ssid !== "" ? root.profiles[uuid].ssid
                                                       : root.profiles[uuid].name;
        }
        return wifiDevConnection;
    }

    readonly property string connectingSsid: connectingName !== "" ? connectingName : activatingSsid

    // Уведомление о неожиданной потере сети. Потерю по клику пользователя
    // и по выключению radio отмечаем флагом и молчим.
    property bool expectedDisconnect: false
    // Предыдущее значение connectedSsid: в onChanged оно уже перезаписано.
    property string previousSsid: ""

    onWifiDevConnectionChanged: {
        if (wifiDevConnection !== "")
            expectedDisconnect = false;
    }

    onConnectedSsidChanged: {
        const lost = previousSsid;
        previousSsid = connectedSsid;
        if (lost === "" || connectedSsid !== "")
            return;
        if (expectedDisconnect || connectingSsid !== "")
            return;
        notifyError("Connection to " + lost + " lost");
    }

    onConnectingSsidChanged: updateModels()

    function disconnectWifi() {
        if (wifiDev === "")
            return;
        cancelActiveConnect();
        connectingName = "";
        expectedDisconnect = true;
        enqueue(["nmcli", "device", "disconnect", wifiDev], () => scheduleRefresh());
    }

    // ───────────── очередь мутирующих команд ─────────────

    function enqueue(args, cb, input) {
        cmdQueue.push({ args: args, cb: cb, input: input || "" });
        pump();
    }

    function pump() {
        if (cmdBusy || cmdQueue.length === 0)
            return;
        cmdBusy = true;
        const job = cmdQueue.shift();
        run(job.args, (code, out, err) => {
            cmdBusy = false;
            if (job.cb)
                job.cb(code, out, err);
            pump();
        }, job.input);
    }

    // ───────────── устройство и опрос ─────────────

    function readDeviceState() {
        run(["nmcli", "-t", "-f", "GENERAL.STATE,GENERAL.CONNECTION",
             "device", "show", wifiDev], (code, out) => {
            if (code !== 0)
                return;
            const cols = splitTerse(lines(out)[0] || "");
            wifiDevState = parseDeviceState(cols[0]);
            wifiDevConnection = cols[1] || "";
        });
    }

    // Пока идёт подключение — следим за состоянием устройства: так видно
    // и наши действия, и автоподключение NM (в том числе после сна).
    readonly property bool connectingBusy: connectingSsid !== ""

    Timer {
        interval: 1000
        repeat: true
        running: root.connectingBusy && root.wifiDev !== ""
        onTriggered: {
            root.readDeviceState();
            root.refreshConnectivity();
        }
    }

    // Пока открыто окно пароля, опрашиваем состояние чаще: NM может
    // обнаружить неверный пароль через несколько секунд после начала
    // подключения (см. руководство, 11.1).
    Timer {
        interval: 500
        repeat: true
        running: root.pendingNetwork !== "" && root.wifiDev !== ""
        onTriggered: {
            root.readDeviceState();
            if (root.connectingName !== "")
                root.refreshConnectivity();
        }
    }

    onConnectingNameChanged: updateModels()
    onPendingNetworkChanged: updateModels()

    // NM не отвечает (выключен, перезапускается): пробуем вернуться к нему
    // сами, чтобы UI восстановился без действий пользователя.
    Timer {
        interval: 10000
        repeat: true
        running: !root.backendAvailable
        onTriggered: root.refresh()
    }

    // Панель открыта: дешёвое обновление списка из кэша NM раз в 5 секунд.
    // Автоматического рескана нет — он рвёт трафик при активном подключении.
    readonly property bool panelOpen: UiState.panel === "internet"

    Timer {
        interval: 5000
        repeat: true
        running: root.panelOpen && root.wifiEnabled && root.wifiDev !== ""
        onTriggered: {
            root.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID",
                      "device", "wifi", "list", "ifname", root.wifiDev, "--rescan", "no"],
                (code, out) => {
                    if (code === 0)
                        root.applyWifiList(out);
                });
        }
    }

    onPanelOpenChanged: {
        syncNativeScanner();
        if (panelOpen) {
            scheduleRefresh();
            scanWifi();
        }
    }

    function refreshConnectivity() {
        run(["nmcli", "-t", "networking", "connectivity"], (code, out) => {
            if (code !== 0)
                return;
            const value = (out || "").trim();
            connectivity = value !== "" ? value : "unknown";
        });
    }

    function checkConnectivity() {
        run(["nmcli", "-t", "networking", "connectivity", "check"], (code, out) => {
            if (code !== 0)
                return;
            const value = (out || "").trim();
            connectivity = value !== "" ? value : "unknown";
        });
    }

    // ───────────── captive portal ─────────────

    function openPortal() {
        getPortalUri((uri) => {
            if (uri === "") {
                notifyError("Could not find the sign-in page");
                return;
            }
            // Сначала пробуем узнать конечный адрес портала без браузера.
            run(["curl", "-s", "-m", "5", "-o", "/dev/null", "-w", "%{redirect_url}", uri],
                (code, out) => {
                    const redirect = (out || "").trim();
                    const target = safeUrl(redirect) ? redirect : uri;
                    run(["xdg-open", target], () => {});
                });
        });
    }

    function safeUrl(url) {
        return /^https?:\/\/[^\s"']+$/.test(url || "");
    }

    function getPortalUri(cb) {
        // URL проверки связности из NM; свойство есть в современных версиях.
        run(["busctl", "get-property", "org.freedesktop.NetworkManager",
             "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager",
             "ConnectivityCheckUri"], (code, out) => {
            let uri = "";
            if (code === 0) {
                const match = (out || "").match(/"([^"]+)"/);
                if (match)
                    uri = match[1];
            }
            if (!safeUrl(uri))
                uri = "http://neverssl.com";
            cb(uri);
        });
    }

    // ───────────── enterprise ─────────────

    Process {
        id: editorProc
        command: ["nm-connection-editor", "--edit", root.enterpriseUuid]
        running: false
        onExited: (code, status) => root.onEditorClosed(code)
    }

    property string enterpriseUuid: ""
    property string editorNetworkName: ""

    function setupEnterprise(network) {
        if (editorRunning) {
            notifyError("Network editor is already open");
            return;
        }
        rememberProfiles();
        // Скелет профиля, чтобы редактор открылся уже с SSID и типом
        // безопасности. Пользователь заменит EAP-метод, если нужно.
        enqueue(["nmcli", "connection", "add", "type", "wifi", "ifname", wifiDev,
                 "con-name", network.name, "ssid", network.name,
                 "wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", "peap",
                 "802-1x.phase2-auth", "mschapv2", "connection.autoconnect", "no"],
            (code, out, err) => {
                if (code !== 0) {
                    connectError = "other";
                    connectErrorText = err;
                    notifyError("Could not create the profile");
                    return;
                }
                const uuid = extractUuid(out);
                if (uuid === "") {
                    notifyError("Could not create the profile");
                    return;
                }
                const cache = root.profileSsid;
                cache[uuid] = network.name;
                root.profileSsid = cache;
                enterpriseUuid = uuid;
                editorNetworkName = network.name;
                // Редактор задаётся здесь: если в системе есть nmtui, но нет
                // GTK-редактора, команду достаточно поменять в одном месте.
                editorProc.command = ["nm-connection-editor", "--edit", uuid];
                editorProc.running = true;
            });
    }

    function extractUuid(out) {
        const match = (out || "").match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
        return match ? match[0] : "";
    }

    function onEditorClosed(exitCode) {
        if (enterpriseUuid === "")
            return;
        const uuid = enterpriseUuid;
        enterpriseUuid = "";
        const name = editorNetworkName;
        editorNetworkName = "";

        // Пользователь мог ничего не настроить: пустой идентификатор 802.1X
        // означает, что профиль остался скелетом — удаляем, чтобы он не
        // копился и не висел в «Saved». Заодно так же выглядит случай, когда
        // редактор не установлен (процесс не запустился).
        run(["nmcli", "-t", "-f", "802-1x.identity", "connection", "show", "uuid", uuid],
            (code, out) => {
                const cols = code === 0 ? splitTerse(lines(out)[0] || "") : [];
                const identity = cols.length > 1 ? cols[1] : "";
                if (identity === "") {
                    if (exitCode !== 0)
                        notifyError("Network editor is not available");
                    enqueue(["nmcli", "connection", "delete", "uuid", uuid], () => scheduleRefresh());
                    return;
                }
                const network = findNetwork(name);
                if (network !== null) {
                    connectSaved(network);
                } else {
                    // Профиль появился, но сети сейчас не видно: пробуем
                    // активировать по uuid, а при неудаче убираем скелет.
                    const generation = ++connectGeneration;
                    connectCancelled = false;
                    connectingName = name;
                    cleanupSsid = name;
                    activeConnectProc = run(["nmcli", "-w", "30", "connection", "up",
                                             "uuid", uuid, "ifname", wifiDev],
                        (code2, out2, err2) => {
                            if (code2 !== 0) {
                                enqueue(["nmcli", "connection", "delete", "uuid", uuid],
                                        () => scheduleRefresh());
                                notifyError("Enterprise network is not configured");
                                connectingName = "";
                                connectError = "other";
                                connectErrorText = err2;
                                scheduleRefresh();
                                return;
                            }
                            onConnectDone(generation, { name: name, security: "enterprise" },
                                          code2, err2, false);
                        });
                }
            });
    }

    // ───────────── ethernet ─────────────

    function disconnectEthernet() {
        if (wiredDev !== "")
            enqueue(["nmcli", "device", "disconnect", wiredDev], () => scheduleRefresh());
    }

    function connectEthernet() {
        if (wiredDev !== "")
            enqueue(["nmcli", "device", "connect", wiredDev], () => scheduleRefresh());
    }

    function requestEthernet() {
        if (ethernetConnected)
            disconnectEthernet();
        else
            connectEthernet();
    }

    // ───────────── уведомления и лог ─────────────

    property bool notificationsEnabled: true

    function notifyError(text) {
        log("error: " + text);
        if (!notificationsEnabled)
            return;
        run(["notify-send", "-a", "Wi-Fi", "Wi-Fi", text], () => {});
    }

    function log(text) {
        console.log("[network] " + text);
    }

    // ───────────── демо-строки ─────────────
    // Нужны, чтобы посмотреть анимации появления/удаления в списках без
    // реальных сетей: qs ipc call bar addWifi / removeWifi.
    // Пока идёт подключение, список не трогаем: его перезапишет refresh.

    function addDemoNetwork() {
        if (scanned.length > 0) {
            log("demo rows are only available without a real scan");
            return;
        }
        const index = demoNetworks.length + 1;
        demoNetworks.push({
            name: "Test_Network_" + index,
            strengthRaw: 25 * (1 + (index % 4)),
            security: index % 2 === 0 ? "psk" : "open",
            bssid: ""
        });
        updateModels();
    }

    function removeDemoNetwork() {
        if (demoNetworks.length === 0)
            return;
        demoNetworks.pop();
        updateModels();
    }

    property var demoNetworks: []

    // ───────────── мониторы NM ─────────────
    //
    // Проверено на nmcli 1.58: `nmcli monitor` печатает только смену общего
    // состояния NM и connectivity, а внешнее `radio wifi off` (Fn-клавиша,
    // rfkill) в нём не видно. `nmcli device monitor` даёт события устройства,
    // но тоже не всегда. Поэтому события — основной путь, а редкий опрос
    // radio (одна дешёвая команда) — страховка от «глухих» изменений.

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        environment: ({ LC_ALL: "C" })
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("Connectivity is now") === 0) {
                    const match = line.match(/'(\w+)'/);
                    if (match)
                        root.connectivity = match[1];
                }
                root.scheduleRefresh();
            }
        }
        onExited: (code, status) => {
            if (root.destroyed)
                return;
            root.backendAvailable = root.backendAvailable && code === 0;
            monitorRestart.restart();
        }
    }

    Process {
        id: deviceMonitor
        command: ["nmcli", "device", "monitor"]
        environment: ({ LC_ALL: "C" })
        running: false
        stdout: SplitParser {
            onRead: line => root.scheduleRefresh()
        }
        onExited: (code, status) => {
            if (!root.destroyed)
                deviceMonitorRestart.restart();
        }
    }

    Timer {
        id: monitorRestart
        interval: 2000
        onTriggered: {
            if (!root.destroyed) {
                monitor.running = true;
                deviceMonitor.running = true;
            }
        }
    }

    Timer {
        id: deviceMonitorRestart
        interval: 2000
        onTriggered: {
            if (!root.destroyed)
                deviceMonitor.running = true;
        }
    }

    // Страховка: даже если NM не прислал событие (внешний rfkill, Fn-клавиша),
    // состояние radio подтянется за несколько секунд. Одна команда чтения.
    Timer {
        interval: 4000
        repeat: true
        running: root.backendAvailable
        onTriggered: {
            root.run(["nmcli", "-t", "-f", "WIFI,WIFI-HW", "radio"], (code, out) => {
                if (code === 0)
                    root.applyResult("radio", code, out, "");
            });
        }
    }

    property bool destroyed: false

    Component.onCompleted: {
        refresh();
        monitor.running = true;
        if (wifiDevice() !== null)
            deviceMonitor.running = true;
        // Индикатор при первом открытии панели: скан стартует, когда станет
        // известно устройство.
        if (panelOpen)
            scanWifi();
    }

    Component.onDestruction: {
        destroyed = true;
        monitor.running = false;
        deviceMonitor.running = false;
        cancelActiveConnect();
    }
}
