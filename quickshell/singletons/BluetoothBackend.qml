pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Bluetooth-бэкенд поверх собственного BlueZ-helper'а
// (scripts/qs-bluetooth-helper.py).
//
// Почему не Quickshell.Bluetooth: модуль не регистрирует BlueZ-агента
// (в src/bluetooth/bluez.cpp нет AgentManager1/RegisterAgent), поэтому
// устройства с подтверждением/авторизацией через него не спарить. У helper'а
// агент есть, и он же держит pair-цепочку, таймауты и работу с D-Bus.
//
// Роли этого файла:
//   * держать один Process с helper'ом и перезапускать его с backoff 1→10 с;
//   * разбирать JSON-события helper'а в две модели (Сохранённые / Новые);
//   * отправлять команды и сопоставлять result с busyAddress;
//   * отдавать UI меню, ошибки и подсказки.
//
// Синхронизацию ListModel делает BluetoothDeviceList: обновление set на месте,
// insert на нужную позицию, move только при нарушении порядка, remove по
// device_removed. Присваивание нового массива не используется — иначе ListView
// пересоздаёт делегаты и теряет прокрутку.
//
// Сторожевых таймеров здесь НЕТ: у helper'а свои таймауты на каждую операцию,
// а busyAddress снимается только по result с тем же id.
Singleton {
    id: root

    // ───────────── helper: процесс ─────────────

    // Путь к helper'у рядом с конфигом (Quickshell.shellDir — каталог shell.qml).
    readonly property string helperPath: Quickshell.shellDir + "/scripts/qs-bluetooth-helper.py"

    // Владелец процесса helper'а. Экземпляр живёт в дереве оболочки (shell.qml)
    // и регистрируется здесь через attachHost(): внутри синглтона Process не
    // запускается вовсе, поэтому процесс вынесен наружу.
    property var host: null

    function attachHost(object) {
        host = object;
        if (host === null)
            return;
        host.lineReceived.connect(line => root.handleLine(line));
        // Процесс упал: снимаем состояние операции, иначе UI остался бы
        // в «Подождите» навсегда.
        host.stopped.connect(() => root.onHelperStopped());
        refreshHostState();
        log("подключён к процессу helper'а");
    }

    // Перечитать состояние процесса с хоста (после событий и подключения).
    function refreshHostState() {
        if (host === null)
            return;
        helperRunning = host.running === true;
        helperRestarts = host.restarts || 0;
    }

    function onHelperStopped() {
        helperRunning = false;
        helperOnline = false;
        busyAddress = "";
        busyRequestId = "";
        connectionPhase = "";
        agentRequest = null;
        refreshHostState();
    }

    // helper прислал ready: можно слать команды.
    property bool helperOnline: false
    // Процесс helper'а жив и число перезапусков. Обычные свойства, а не
    // привязки к host: привязка к ещё не подключённому host давала undefined
    // и ломалась. Обновляются в attachHost(), в handleLine() и по stopped().
    property bool helperRunning: false
    property int helperRestarts: 0

    // ───────────── состояние адаптера ─────────────

    property string adapterPath: ""
    property string adapterId: ""
    // Свойства адаптера из снимка и событий adapter.
    property var adapterProps: ({})

    readonly property bool hasAdapter: adapterPath !== ""
    // Bluetooth включён. Только чтение: питание меняется setEnabled().
    readonly property bool enabled: adapterProps.Powered === true
    // rfkill: BlueZ отдаёт PowerState = "off-blocked".
    readonly property bool blocked: adapterProps.PowerState === "off-blocked"
    readonly property bool available: hasAdapter && !blocked
    readonly property bool discoverable: adapterProps.Discoverable === true

    // Есть ли хотя бы одно подключённое устройство: для значка в баре.
    readonly property bool anyConnected: {
        for (const path in devices) {
            if (devices[path] && devices[path].Connected === true)
                return true;
        }
        return false;
    }
    // Идёт поиск: состояние BlueZ плюс наш запрос до подтверждения.
    readonly property bool scanning: adapterProps.Discovering === true || scanRequested

    readonly property string adapterStateName: {
        if (!hasAdapter)
            return "unavailable";
        const state = adapterProps.PowerState;
        if (typeof state === "string" && state !== "")
            return state;
        return enabled ? "on" : "off";
    }

    // ───────────── публичные модели ─────────────

    // Сохранённые (paired/bonded): подключённые первыми, затем по имени.
    readonly property ListModel pairedDevices: pairedModel
    // Новые (не спаренные) с именем: по имени, затем по адресу.
    readonly property ListModel newDevices: newModel
    // Новые без имени: BlueZ отдаёт только MAC. UI показывает их свёрнуто
    // («Показать ещё»), чтобы список не забивался безымянными адресами.
    readonly property ListModel unnamedDevices: unnamedModel

    ListModel { id: pairedModel }
    ListModel { id: newModel }
    ListModel { id: unnamedModel }

    BluetoothDeviceList {
        id: pairedSync
        model: pairedModel
        keyOf: (item) => item.address
        compare: (a, b) => root.comparePaired(a, b)
    }

    BluetoothDeviceList {
        id: newSync
        model: newModel
        keyOf: (item) => item.address
        compare: (a, b) => root.compareNew(a, b)
    }

    BluetoothDeviceList {
        id: unnamedSync
        model: unnamedModel
        keyOf: (item) => item.address
        compare: (a, b) => root.compareNew(a, b)
    }

    // ───────────── состояние операции ─────────────

    // MAC, по которому идёт операция. Ставится при отправке команды и
    // снимается ТОЛЬКО по result с тем же id.
    property string busyAddress: ""
    property string busyRequestId: ""
    // Фаза операции: "" | "pairing" | "trusting" | "connecting" | "disconnecting".
    property string connectionPhase: ""
    // Идёт спаривание: пункт меню становится «Отменить».
    readonly property bool pairingInProgress: busyAddress !== ""
            && connectionPhase === "pairing"
    // Последняя ошибка, подсказка и адрес неудачной попытки.
    property string lastError: ""
    property string lastErrorHint: ""
    property string lastFailedAddress: ""
    // Запрос агента, ждущий ответа UI (null — нет запроса).
    property var agentRequest: null
    // Запрос скана, ещё не подтверждённый BlueZ: индикатор включается сразу.
    property bool scanRequested: false
    // Вызывался ли pair в текущей попытке: по этому признаку не делается
    // автоповтор (иначе повторилось бы и спаривание).
    property bool pairCalledForAttempt: false
    // Один автоматический повтор уже сделан.
    property bool autoRetryDone: false
    // Адрес устройства, для которого открыто контекстное меню.
    property string menuAddress: ""

    // Устройства: path → props; address(верхний регистр) → path.
    property var devices: ({})
    property var addressIndex: ({})

    // ───────────── сигналы ─────────────

    signal connectionFailed(string address, string reason)
    signal deviceConnected(string address)
    signal deviceDisconnected(string address)
    signal devicePaired(string address)
    signal deviceForgotten(string address)
    signal forgetFailed(string address, string reason)
    signal scanStopped()
    signal discoverabilityChanged()
    signal agentRequested(var request)

    // ───────────── разбор событий helper'а ─────────────

    function handleLine(line) {
        refreshHostState();
        let event = null;
        try {
            event = JSON.parse(line);
        } catch (e) {
            log("не разобрал событие helper'а: " + line);
            return;
        }
        const kind = event.ev;
        if (kind === "ready")
            handleReady(event);
        else if (kind === "adapter")
            handleAdapter(event);
        else if (kind === "adapter_removed")
            handleAdapterRemoved();
        else if (kind === "device_added" || kind === "device") {
            storeDevice(event.path, event.props);
            updateModels();
        } else if (kind === "device_removed") {
            forgetDevicePath(event.path);
            updateModels();
        } else if (kind === "phase") {
            connectionPhase = event.phase || "";
        } else if (kind === "agent") {
            agentRequest = event;
            agentRequested(event);
            log("запрос агента: " + event.request + " от "
                + (event.address || "—"));
        } else if (kind === "agent_registered") {
            log("агент helper'а зарегистрирован: " + event.capability);
        } else if (kind === "result") {
            handleResult(event);
        } else if (kind === "helper") {
            if (event.online === false)
                helperOnline = false;
        } else if (kind === "error") {
            setError("", String(event.error || "ошибка helper'а"));
        }
    }

    function handleReady(event) {
        helperOnline = true;
        // Сбрасываем backoff перезапуска: helper поднялся успешно.
        if (host !== null)
            host.restartDelayMs = 1000;
        const adapters = event.adapters || [];
        if (adapters.length > 0) {
            adapterPath = adapters[0].path || "";
            adapterId = adapters[0].id || "";
            adapterProps = collectAdapterProps(adapters[0]);
        } else {
            adapterPath = "";
            adapterId = "";
            adapterProps = ({});
        }
        devices = ({});
        addressIndex = ({});
        const list = event.devices || [];
        for (let i = 0; i < list.length; ++i)
            storeDevice(list[i].path, list[i]);
        updateModels();
        log("helper готов: адаптер " + (adapterId || "нет")
            + ", устройств " + list.length);
    }

    // В событии ready адаптер лежит отдельным объектом: отбираем свойства,
    // отбрасывая служебные поля.
    function collectAdapterProps(adapter) {
        const out = ({});
        for (const key in adapter) {
            if (key === "path" || key === "id")
                continue;
            out[key] = adapter[key];
        }
        return out;
    }

    function handleAdapter(event) {
        adapterProps = event.props || ({});
        // BlueZ подтвердил остановку скана — снимаем наш запрос.
        if (adapterProps.Discovering !== true)
            scanRequested = false;
        updateModels();
    }

    function handleAdapterRemoved() {
        adapterPath = "";
        adapterId = "";
        adapterProps = ({});
        devices = ({});
        addressIndex = ({});
        scanRequested = false;
        updateModels();
    }

    function storeDevice(path, props) {
        if (!path)
            return;
        const copy = ({});
        for (const key in props) {
            if (key === "path")
                continue;
            copy[key] = props[key];
        }
        const current = devices;
        current[path] = copy;
        devices = current;
        if (copy.Address) {
            const index = addressIndex;
            index[String(copy.Address).toUpperCase()] = path;
            addressIndex = index;
        }
    }

    function forgetDevicePath(path) {
        const entry = devices[path];
        if (entry !== undefined && entry.Address) {
            const index = addressIndex;
            delete index[String(entry.Address).toUpperCase()];
            addressIndex = index;
        }
        const current = devices;
        delete current[path];
        devices = current;
    }

    // Результат операции: busy снимается только по своему id.
    function handleResult(event) {
        const address = event.address || "";
        // Перечитываем состояние после КАЖДОЙ операции. BlueZ во время
        // спаривания успевает выставить Connected=true и откатить его; без
        // пересинхронизации это временное значение залипало в модели, и
        // устройство в «Доступных» рисовалось подключённым.
        send("snapshot", {});
        const phase = connectionPhase;
        if (event.id !== undefined && event.id === busyRequestId) {
            busyAddress = "";
            busyRequestId = "";
        }
        connectionPhase = "";

        if (event.ok === true) {
            autoRetryDone = false;
            pairCalledForAttempt = false;
            if (phase === "disconnecting")
                deviceDisconnected(address);
            else
                deviceConnected(address);
            return;
        }

        const text = String(event.error || "операция не удалась");
        setError(address, text);

        // Один автоповтор — только «устройство не ответило» и только если pair
        // в этой попытке не вызывался.
        if (!autoRetryDone && !pairCalledForAttempt
                && (text.indexOf("Page Timeout") >= 0
                    || text.indexOf("ConnectionAttemptFailed") >= 0)) {
            autoRetryDone = true;
            log("повтор подключения после: " + text);
            connectDevice(address);
            return;
        }
        if (phase === "disconnecting") {
            deviceDisconnected(address);
            return;
        }
        connectionFailed(address, text);
    }

    function setError(address, text) {
        lastError = text;
        lastErrorHint = hintFor(text);
        lastFailedAddress = address;
        log("ошибка: " + text + " | " + lastErrorHint);
    }

    // Тексты ошибок BlueZ → что делать пользователю.
    function hintFor(text) {
        const value = String(text);
        if (value.indexOf("AuthenticationCanceled") >= 0)
            return "Устройство отменило сопряжение. Обычно оно подключено к другому устройству (телефону) или вышло из режима сопряжения.";
        if (value.indexOf("AuthenticationRejected") >= 0)
            return "Устройство отклонило запрос. Проверьте, принято ли подтверждение на самом устройстве.";
        if (value.indexOf("AuthenticationTimeout") >= 0)
            return "Устройство не подтвердило сопряжение вовремя. Попробуйте ещё раз.";
        if (value.indexOf("AuthenticationFailed") >= 0)
            return "Не удалось аутентифицироваться. Уберите устройство из списка и спарьте заново.";
        if (value.indexOf("ConnectionAttemptFailed") >= 0
                || value.indexOf("Page Timeout") >= 0)
            return "Устройство не отвечает. Проверьте, что оно включено, рядом и не подключено к другому устройству.";
        if (value.indexOf("profile-unavailable") >= 0)
            return "Устройство подключилось, но нужный профиль недоступен. Попробуйте переподключить.";
        if (value.indexOf("AlreadyExists") >= 0)
            return "Устройство уже спарено или подключено.";
        if (value.indexOf("InProgress") >= 0)
            return "Операция уже идёт, дождитесь её завершения.";
        if (value.indexOf("NotReady") >= 0)
            return "Адаптер выключен или ещё не поднялся. Включите Bluetooth и повторите.";
        if (value.indexOf("adapter") >= 0 || value.indexOf("адаптер") >= 0)
            return "Bluetooth-адаптер не найден.";
        if (value.indexOf("не найдено") >= 0)
            return "BlueZ больше не видит это устройство.";
        if (value.indexOf("ServiceUnknown") >= 0)
            return "BlueZ не принял вызов: возможно, bluetoothd перезапускается. Повторите.";
        return "";
    }

    // ───────────── отправка команд ─────────────

    property int requestCounter: 0

    function send(cmd, extra) {
        if (host === null) {
            log("хост helper'а не подключён, команда " + cmd + " пропущена");
            return "";
        }
        if (!helperRunning) {
            log("helper не запущен, команда " + cmd + " пропущена");
            return "";
        }
        requestCounter++;
        const id = String(requestCounter);
        const payload = { id: id, cmd: cmd };
        if (extra) {
            for (const key in extra)
                payload[key] = extra[key];
        }
        if (!host.send(JSON.stringify(payload) + "\n"))
            return "";
        return id;
    }

    // Отправить команду и занять адрес до прихода result с этим id.
    function sendBusy(cmd, address, extra) {
        if (busyAddress !== "")
            return "";
        const id = send(cmd, extra);
        if (id === "")
            return "";
        busyAddress = address;
        busyRequestId = id;
        return id;
    }

    // ───────────── адаптер ─────────────

    function setEnabled(value) {
        if (!hasAdapter)
            return false;
        if (value && blocked) {
            setError("", "Bluetooth заблокирован (rfkill): снимите блокировку (rfkill unblock bluetooth).");
            return false;
        }
        scanRequested = false;
        send("power", { value: value });
        return true;
    }

    function toggleEnabled() {
        setEnabled(!enabled);
    }

    function setDiscoverable(value) {
        if (!hasAdapter)
            return false;
        send("discoverable", { value: value });
        return true;
    }

    function toggleDiscoverable() {
        setDiscoverable(!discoverable);
    }

    // ───────────── сканирование ─────────────

    function startScan() {
        if (!hasAdapter || !enabled) {
            scanRequested = false;
            return false;
        }
        scanRequested = true;
        send("scan", { start: true });
        return true;
    }

    function stopScan() {
        scanRequested = false;
        if (!hasAdapter)
            return false;
        send("scan", { start: false });
        return true;
    }

    function toggleScan() {
        if (scanning)
            stopScan();
        else
            startScan();
    }

    // ───────────── подключение ─────────────

    // Основное действие строки. Новое (не спаренное) устройство идёт через
    // pair-цепочку helper'а, сохранённое — сразу connect.
    function toggleConnection(device) {
        if (pairingInProgress) {
            cancelConnection();
            return;
        }
        const item = resolve(device);
        if (item === null || busyAddress !== "")
            return;
        autoRetryDone = false;
        if (item.connected === true) {
            disconnectDevice(item);
            return;
        }
        if (item.paired === true || item.bonded === true) {
            connectDevice(item);
            return;
        }
        pairCalledForAttempt = true;
        connectionPhase = "pairing";
        sendBusy("pair", item.address, { address: item.address });
    }

    function connectDevice(device) {
        const item = resolve(device);
        if (item === null || busyAddress !== "")
            return;
        connectionPhase = "connecting";
        sendBusy("connect", item.address, { address: item.address });
    }

    function disconnectDevice(device) {
        const item = resolve(device);
        if (item === null || busyAddress !== "")
            return;
        connectionPhase = "disconnecting";
        sendBusy("disconnect", item.address, { address: item.address });
    }

    // Отмена спаривания: helper отменит Pair, операция завершится result'ом.
    function cancelConnection() {
        if (busyAddress === "")
            return;
        send("cancel_pair", { address: busyAddress });
    }

    // Ответ на запрос агента (PIN, passkey, подтверждение).
    function replyAgent(accept, value) {
        const request = agentRequest;
        if (request === null)
            return;
        send("agent_reply", {
            address: request.address || "",
            accept: accept === true,
            value: value === undefined || value === null ? "" : String(value)
        });
        agentRequest = null;
    }

    function forgetDevice(device) {
        const item = resolve(device);
        if (item === null || busyAddress !== "")
            return;
        sendBusy("remove", item.address, { address: item.address });
    }

    function openMenu(device) {
        if (typeof device === "string")
            menuAddress = device;
        else
            menuAddress = device && device.address ? device.address : "";
        refreshMenu();
    }

    function closeMenu() {
        menuAddress = "";
        currentMenu = null;
    }

    // ───────────── меню ─────────────

    // Данные меню. busy → «Подождите…», фаза pairing → «Отменить».
    function deviceMenu(device) {
        const item = resolve(device);
        if (item === null) {
            return {
                name: "", address: "", state: "disconnected", connected: false,
                batteryKnown: false, batteryPercent: -1, actionLabel: "",
                canToggle: false, canForget: false, cancellable: false,
                paired: false
            };
        }
        const busy = busyAddress === item.address;
        const cancellable = busy && pairingInProgress;
        const connected = item.connected === true;
        const hasBattery = connected && typeof item.battery === "number"
                && item.battery >= 0;
        return {
            name: deviceLabel(item),
            address: item.address,
            state: stateName(item),
            connected: connected,
            // Battery1.Percentage у BlueZ уже в процентах.
            batteryKnown: hasBattery,
            batteryPercent: hasBattery ? Math.round(item.battery) : -1,
            actionLabel: actionLabelFor(stateName(item), busy, cancellable,
                                        item.paired === true || item.bonded === true),
            canToggle: !busy || cancellable,
            canForget: !busy && (item.paired === true || item.bonded === true),
            cancellable: cancellable,
            paired: item.paired === true || item.bonded === true
        };
    }

    // Данные открытого меню. Обычное свойство: обновляется в updateModels()
    // и при открытии/закрытии. Привязка не пересчитывалась после отключения,
    // и меню продолжало показывать «Отключиться».
    property var currentMenu: null

    function refreshMenu() {
        if (menuAddress === "") {
            currentMenu = null;
            return;
        }
        const item = deviceByAddress(menuAddress);
        currentMenu = item === null ? null : deviceMenu(item);
    }

    function actionLabelFor(state, busy, cancellable, paired) {
        if (cancellable)
            return "Отменить";
        if (state === "connecting")
            return "Подключение…";
        if (state === "disconnecting")
            return "Отключение…";
        if (busy)
            return "Подождите…";
        if (state === "connected")
            return "Отключиться";
        return paired ? "Подключиться" : "Спарить и подключить";
    }

    // ───────────── разрешение устройства ─────────────

    // Принимает MAC или объект с address. Имя ключом не используется: имена
    // могут совпадать, поэтому UI обязан передавать address.
    function resolve(device) {
        if (device === null || device === undefined)
            return null;
        if (typeof device === "string")
            return deviceByAddress(device);
        if (device.address !== undefined)
            return deviceByAddress(device.address);
        return null;
    }

    // Копия свойств устройства с полями address и path.
    function deviceByAddress(address) {
        if (!address)
            return null;
        const path = addressIndex[String(address).toUpperCase()];
        if (path === undefined)
            return null;
        const entry = devices[path];
        if (entry === undefined)
            return null;
        return {
            path: path,
            address: entry.Address || String(address).toUpperCase(),
            name: deviceLabel(entry),
            icon: entry.Icon || "",
            paired: entry.Paired === true,
            bonded: entry.Bonded === true,
            connected: entry.Connected === true,
            trusted: entry.Trusted === true,
            blocked: entry.Blocked === true,
            battery: typeof entry.Battery === "number" ? entry.Battery : -1,
            // Исходные свойства BlueZ — для тех, кому нужен полный набор.
            raw: entry
        };
    }

    // ───────────── мапперы ─────────────

    // Похожа ли строка на MAC-адрес. BlueZ для устройств без имени кладёт в
    // Alias сам адрес (через дефис: "4D-AE-92-22-A1-7E"), и такой «псевдоним»
    // нельзя показывать как имя — иначе в списке вместо названий адреса.
    function isAddressLike(text) {
        const value = String(text === null || text === undefined ? "" : text).trim();
        if (value === "")
            return true;
        return /^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/.test(value);
    }

    // Настоящее ли это имя (не пустое и не адрес).
    function hasRealName(device) {
        if (device === null || device === undefined)
            return false;
        const alias = device.Alias || "";
        const name = device.Name || "";
        if (alias !== "" && !isAddressLike(alias))
            return true;
        return name !== "" && !isAddressLike(name);
    }

    function deviceLabel(device) {
        if (device === null || device === undefined)
            return "";
        // Сначала нормализованное имя (из deviceByAddress), затем Alias, затем
        // Name; всё, что похоже на адрес, пропускаем.
        const candidates = [device.name, device.Alias, device.Name];
        for (let i = 0; i < candidates.length; ++i) {
            const value = candidates[i];
            if (value && value !== "" && !isAddressLike(value))
                return value;
        }
        return device.address || device.Address || "";
    }

    function stateName(device) {
        if (device === null || device === undefined)
            return "disconnected";
        if (device.connected === true || device.Connected === true)
            return "connected";
        const address = device.address || device.Address || "";
        if (busyAddress !== "" && busyAddress === address) {
            if (connectionPhase === "disconnecting")
                return "disconnecting";
            if (connectionPhase !== "")
                return "connecting";
        }
        return "disconnected";
    }

    // «Иконка BlueZ → глиф Nerd Font». Кодпоинты Font Awesome 4.7: только они
    // есть в JetBrainsMono Nerd Font.
    readonly property var iconGlyphs: ({
        "audio-headset": "\uf025", "audio-headphones": "\uf025",
        "audio-card": "\uf028", "audio-speakers": "\uf028",
        "audio-input-microphone": "\uf130",
        "input-keyboard": "\uf11c", "input-mouse": "\uf245",
        "input-tablet": "\uf10a", "input-gaming": "\uf11b",
        "phone": "\uf10b",
        "camera-video": "\uf03d", "camera-photo": "\uf030",
        "video-display": "\uf26c", "computer": "\uf108",
        "printer": "\uf02f", "scanner": "\uf02d",
        "multimedia-player": "\uf001", "drive-harddisk": "\uf0a0",
        "modem": "\uf1eb", "network-wireless": "\uf1eb",
        "watch": "\uf017", "car": "\uf1b9",
        // Заглушка — общий значок Bluetooth, а не «вопрос»: для устройств без
        // Icon вопросительный знак выглядел как ошибка.
        "bluetooth": "\uf293", "unknown": "\uf293"
    })

    function iconForDevice(device) {
        const icon = device === null || device === undefined
                ? "" : (device.Icon || "");
        return iconForBluezIcon(icon);
    }

    function iconForBluezIcon(bluezIcon) {
        const key = String(bluezIcon || "").toLowerCase();
        if (key !== "" && iconGlyphs[key] !== undefined)
            return iconGlyphs[key];
        return iconGlyphs["unknown"];
    }

    function iconNameForDevice(device) {
        const icon = device === null || device === undefined
                ? "" : (device.Icon || "");
        return String(icon || "bluetooth");
    }

    // ───────────── модели ─────────────

    // Снимок устройства для ListModel: только примитивы.
    function toItem(device) {
        const connected = device.Connected === true;
        const hasBattery = connected && typeof device.Battery === "number";
        return {
            name: deviceLabel(device),
            address: device.Address || "",
            // true только для настоящего имени: устройства, у которых BlueZ
            // отдал вместо имени адрес, уходят в свёрнутую секцию.
            hasName: hasRealName(device),
            icon: iconForDevice(device),
            paired: device.Paired === true,
            bonded: device.Bonded === true,
            connected: connected,
            trusted: device.Trusted === true,
            connecting: stateName(device) === "connecting",
            state: stateName(device),
            batteryPercent: hasBattery ? Math.round(device.Battery) : -1
        };
    }

    function updateModels() {
        const paired = [];
        const named = [];
        const unnamed = [];
        for (const path in devices) {
            const item = toItem(devices[path]);
            if (item.paired || item.bonded)
                paired.push(item);
            else if (item.hasName)
                named.push(item);
            else
                unnamed.push(item);
        }
        paired.sort(comparePaired);
        named.sort(compareNew);
        unnamed.sort(compareNew);
        pairedSync.sync(paired);
        newSync.sync(named);
        unnamedSync.sync(unnamed);
        computeSummary();
        refreshMenu();
    }

    // «Сохранённые»: подключённые первыми, затем по имени, затем по адресу.
    function comparePaired(a, b) {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        return compareNew(a, b);
    }

    // «Новые»: по имени, затем по адресу.
    function compareNew(a, b) {
        const an = String(a.name || "").toLowerCase();
        const bn = String(b.name || "").toLowerCase();
        if (an !== bn)
            return an < bn ? -1 : 1;
        if (a.address === b.address)
            return 0;
        return a.address < b.address ? -1 : 1;
    }

    // ───────────── сводка и служебное ─────────────

    // Сводка для плитки быстрых настроек. Обычное свойство: обновляется в
    // updateModels(), чтобы не зависеть от переприсваивания devices.
    property string connectedSummary: "Недоступен"

    function computeSummary() {
        if (!hasAdapter) {
            connectedSummary = "Недоступен";
            return;
        }
        if (!enabled) {
            connectedSummary = "Выключен";
            return;
        }
        for (const path in devices) {
            if (devices[path].Connected === true) {
                connectedSummary = deviceLabel(devices[path]);
                return;
            }
        }
        connectedSummary = "Нет подключений";
    }

    // Скрыть текст ошибки, не забывая адрес для кнопки «Повторить».
    function clearError() {
        lastError = "";
    }

    function clearErrorState() {
        lastError = "";
        lastErrorHint = "";
        lastFailedAddress = "";
    }

    // Перечитать состояние из BlueZ (отладка и тесты).
    function refresh() {
        send("snapshot", {});
    }

    function log(message) {
        console.log("[BluetoothBackend] " + message);
    }

    Component.onCompleted: log("бэкенд запущен, helper: " + helperPath)
}
