pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Поисковый бэкенд дока. По умолчанию пытается использовать Elephant;
// если его нет — показывает предупреждение в настройках и ищет встроенным
// провайдером. Результаты — единый список объектов для ScriptModel/ListView.
Singleton {
    id: root

    // --- настройки поиска -------------------------------------------------
    // По умолчанию Elephant включён и мы пытаемся к нему подключиться.
    property bool elephantEnabled: true
    // Имена провайдеров Elephant, выбранные в настройках.
    property var enabledProviders: []

    // --- состояние Elephant ----------------------------------------------
    property var providers: []
    property bool elephantAvailable: false
    // listproviders отвечает и без запущенного сервиса: так мы отличаем
    // «не установлен» от «установлен, но сервис не запущен».
    property bool installed: false
    property bool probing: false
    property bool serviceStarting: false
    property bool autoStartTried: false
    property bool loading: false
    property string lastError: ""
    property int lastQid: 0

    // --- текущий запрос и результаты --------------------------------------
    property string query: ""
    property var results: []

    // Встроенный поиск нужен и как fallback, и когда Elephant выключен.
    readonly property bool useBuiltin: !root.elephantEnabled
                                      || !root.elephantAvailable
                                      || root.enabledProviders.length === 0
    readonly property string summary: "elephant=" + (root.elephantEnabled ? "on" : "off")
        + " available=" + root.elephantAvailable
        + " installed=" + root.installed
        + " probing=" + root.probing
        + " starting=" + root.serviceStarting
        + " providers=" + (root.providers.length > 0 ? root.providers.join("|") : "-")
        + " enabled=" + (root.enabledProviders.length > 0 ? root.enabledProviders.join("|") : "-")
        + " builtin=" + root.useBuiltin
        + " results=" + root.results.length

    // Elephant возвращает exit 2 и «unexpected end of JSON input», когда
    // просто ничего не нашёл. Это не потеря соединения и не повод уходить
    // на встроенный поиск.
    function isEmptyResultError(text) {
        const value = String(text || "");
        return value.indexOf("unexpected end of JSON") >= 0
            || value.indexOf("unexpected end of json") >= 0;
    }

    // --- Elephant: список провайдеров ------------------------------------
    Process {
        id: listProc
        command: ["elephant", "listproviders"]
        running: false
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.applyProviders(listOut.text)
        }
        stderr: StdioCollector {}
        onExited: (code, status) => {
            listWatchdog.stop();
            if (code !== 0) {
                root.installed = false;
                root.elephantLost("listproviders: " + code);
            } else {
                root.installed = true;
                if (root.providers.length === 0)
                    root.elephantLost("нет провайдеров");
                else
                    root.probe();
            }
        }
    }

    // --- Elephant: проверка соединения -----------------------------------
    Process {
        id: probeProc
        command: ["elephant", "query", "--json", root.probeArg]
        running: false
        stdout: StdioCollector {
            id: probeOut
            onStreamFinished: {}
        }
        stderr: StdioCollector {
            id: probeErr
            onStreamFinished: root.lastError = (probeErr.text || "").trim()
        }
        onExited: (code, status) => {
            probeWatchdog.stop();
            root.probing = false;
            if (code !== 0 && !root.isEmptyResultError(root.lastError)) {
                root.elephantLost(root.lastError || ("probe: " + code));
                return;
            }
            root.installed = true;
            root.elephantAvailable = true;
            root.serviceStarting = false;
            root.lastError = "";
            if (root.enabledProviders.length === 0) {
                root.enabledProviders = ["desktopapplications"];
            }
            root.requestSearch();
        }
    }

    readonly property string probeArg: {
        const provider = root.enabledProviders.length > 0
            ? root.enabledProviders[0]
            : (root.providers.length > 0 ? root.providers[0] : "desktopapplications");
        return provider + ";;1";
    }

    Timer {
        id: listWatchdog
        interval: 3500
        onTriggered: {
            if (!root.probing)
                return;
            if (listProc.running)
                listProc.running = false;
            root.probing = false;
            root.elephantLost("таймаут списка провайдеров");
        }
    }

    Timer {
        id: recovery
        interval: 2500
        onTriggered: {
            if (!DockState.expanded || root.elephantAvailable || !root.elephantEnabled
                    || !root.installed || root.probing || root.serviceStarting)
                return;
            root.probe();
        }
    }

    Timer {
        id: probeWatchdog
        interval: 3500
        onTriggered: {
            if (!root.probing)
                return;
            if (probeProc.running)
                probeProc.running = false;
            root.probing = false;
            root.elephantLost("таймаут подключения");
        }
    }

    // --- Elephant: запрос -------------------------------------------------
    // Один процесс за раз: если запрос устарел, его результат просто не
    // коммитим, а после выхода запускаем актуальный. Это убирает гонки
    // abort/restart при быстром наборе.
    Process {
        id: queryProc
        command: ["elephant", "query", "--json", root.runningArg]
        running: false
        stdout: StdioCollector {
            id: queryOut
            onStreamFinished: root.parseElephant(queryOut.text)
        }
        stderr: StdioCollector {
            id: queryErr
            onStreamFinished: root.lastError = (queryErr.text || "").trim()
        }
        onExited: (code, status) => {
            const arg = root.runningArg;
            root.runningArg = "";
            if (code !== 0) {
                // Пустой результат Elephant — это не ошибка связи.
                if (root.isEmptyResultError(root.lastError)) {
                    root.installed = true;
                    root.elephantAvailable = true;
                    root.lastError = "";
                    if (!root.useBuiltin && arg === root.elephantArg) {
                        // Обычно список пуст; если часть строк успела
                        // прийти, показываем её, а не теряем.
                        root.results = root.pendingResults;
                        root.lastQid = root.pendingQid;
                        root.lastResultArg = arg;
                        root.loading = false;
                    }
                    root.pumpQuery();
                    return;
                }
                if (!root.useBuiltin && arg === root.elephantArg)
                    root.elephantLost(root.lastError || ("query: " + code));
                else
                    root.loading = false;
                root.pumpQuery();
                return;
            }

            root.elephantAvailable = true;
            if (!root.useBuiltin && arg === root.elephantArg) {
                root.results = root.pendingResults;
                root.lastQid = root.pendingQid;
                root.lastResultArg = arg;
                root.loading = false;
            } else if (root.useBuiltin) {
                root.loading = false;
                root.results = root.builtinResults();
                root.lastResultArg = "";
            }
            root.pumpQuery();
        }
    }

    property var pendingResults: []
    property int pendingQid: 0
    property string runningArg: ""
    property string lastResultArg: ""

    readonly property string elephantArg: {
        const providerList = root.enabledProviders.join(",");
        const clean = root.query.replace(/[;\n\r]/g, " ").trim();
        return providerList + ";" + clean + ";32";
    }

    Timer {
        id: debounce
        interval: 80
        onTriggered: root.runElephant()
    }

    function runElephant() {
        if (root.useBuiltin || !DockState.expanded)
            return;
        if (queryProc.running)
            return; // актуальный запрос уйдёт после выхода текущего
        if (root.lastResultArg === root.elephantArg)
            return;
        root.runQueryNow();
    }

    function runQueryNow() {
        if (root.useBuiltin || !DockState.expanded || queryProc.running)
            return;
        root.runningArg = root.elephantArg;
        root.pendingResults = [];
        root.pendingQid = 0;
        root.lastError = "";
        root.loading = true;
        queryProc.running = true;
    }

    function pumpQuery() {
        if (root.useBuiltin || !DockState.expanded || queryProc.running)
            return;
        if (root.lastResultArg !== root.elephantArg) {
            root.loading = true;
            debounce.restart();
        }
    }

    // --- Elephant: сервис -------------------------------------------------
    // Если пакет Elephant установлен, а сервис не запущен, поднимаем его
    // сами: иначе «elephant есть» и «elephant доступен» расходятся.
    Process {
        id: serviceProc
        // Отделяем сервис от процесса оболочки: иначе hot reload убивает
        // Elephant, и следующее открытие панели на пару секунд остаётся
        // без него. Вывод в /dev/null, чтобы не держать каналы.
        command: ["sh", "-c", "setsid -f elephant >/dev/null 2>&1"]
        running: false
        stdout: SplitParser {
            onRead: line => {}
        }
        stderr: SplitParser {
            onRead: line => {
                if (line !== "")
                    root.lastError = line;
            }
        }
        onExited: (code, status) => {
            root.serviceStarting = false;
            if (!root.elephantAvailable && code !== 0)
                root.elephantLost(root.lastError || ("elephant: " + code));
        }
    }

    Timer {
        id: serviceRetry
        interval: 900
        onTriggered: {
            root.serviceStarting = false;
            root.probe();
        }
    }

    function startService() {
        if (root.serviceStarting || root.elephantAvailable)
            return;
        root.autoStartTried = true;
        root.lastError = "";
        if (serviceProc.running) {
            root.probe();
            return;
        }
        root.serviceStarting = true;
        serviceProc.running = true;
        serviceRetry.restart();
    }

    // --- Elephant: activate -----------------------------------------------
    Process {
        id: activateProc
        command: ["elephant", "activate", root.activateArg]
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    property string activateArg: ""
    property bool activating: false

    Timer {
        id: startActivate
        interval: 0
        onTriggered: {
            root.activating = true;
            activateProc.running = true;
        }
    }

    // --- настройки --------------------------------------------------------
    property bool restoring: false

    onElephantEnabledChanged: root.store("dock.elephant", root.elephantEnabled)
    onEnabledProvidersChanged: root.store("dock.providers", root.enabledProviders)

    function store(key, value) {
        if (root.restoring || !Settings.loaded)
            return;
        Settings.setValue(key, value);
    }

    function setElephantEnabled(value) {
        root.elephantEnabled = value === true;
        if (root.elephantEnabled)
            root.refresh();
        else
            root.requestSearch();
    }

    function toggleProvider(name) {
        const list = root.enabledProviders.slice();
        const index = list.indexOf(name);
        if (index >= 0)
            list.splice(index, 1);
        else
            list.push(name);
        root.enabledProviders = list;
        root.requestSearch();
    }

    function hasProvider(name) {
        return root.enabledProviders.indexOf(name) >= 0;
    }

    function providerLabel(name) {
        if (name === "desktopapplications")
            return "Приложения";
        if (name.indexOf("menus:") === 0)
            return "Меню: " + name.substring(6);
        return name;
    }

    function restore() {
        root.restoring = true;
        root.elephantEnabled = Settings.value("dock.elephant", true) === true;
        // Список провайдеров может быть ещё не прочитан: сохраняем имена
        // как есть, а пересечение с доступными делаем после listproviders.
        const saved = Settings.value("dock.providers", []);
        root.enabledProviders = Array.isArray(saved) ? saved.map(String) : [];
        root.restoring = false;
        // Настройки могли прийти уже после открытия панели — перезапускаем
        // текущий запрос, чтобы выбранные провайдеры применились сразу.
        root.requestSearch();
    }

    function validProviders(saved) {
        if (!Array.isArray(saved))
            return [];
        const out = [];
        for (let i = 0; i < saved.length; ++i) {
            const name = String(saved[i]);
            if (root.providers.indexOf(name) >= 0 && out.indexOf(name) < 0)
                out.push(name);
        }
        return out;
    }

    Connections {
        target: Settings
        function onLoadedChanged() {
            if (Settings.loaded)
                root.restore();
        }
    }

    Connections {
        target: DockApps
        function onAllChanged() {
            if (root.useBuiltin)
                root.results = root.builtinResults();
        }
    }

    Component.onCompleted: {
        if (Settings.loaded)
            root.restore();
        root.refresh();
        // Не ждём listproviders, чтобы не показывать встроенный поиск
        // первые секунды: сервис проверяем сразу по известному провайдеру.
        if (root.elephantEnabled)
            root.probe();
    }

    // --- жизненный цикл ---------------------------------------------------
    function refresh() {
        if (root.probing)
            return;
        root.probing = true;
        root.lastError = "";
        listWatchdog.restart();
        listProc.running = true;
    }

    function probeIfNeeded() {
        if (root.probing || root.elephantAvailable || root.providers.length === 0)
            return;
        root.probe();
    }

    function probe() {
        if (root.elephantAvailable) {
            root.requestSearch();
            return;
        }
        if (probeProc.running)
            return;
        root.probing = true;
        root.lastError = "";
        probeWatchdog.restart();
        probeProc.running = true;
    }

    function elephantLost(reason) {
        root.elephantAvailable = false;
        root.probing = false;
        root.lastError = reason;
        root.loading = false;
        root.results = root.builtinResults();
        root.lastResultArg = "";

        // Установленный, но не запущенный сервис поднимаем один раз сами.
        if (root.installed && root.elephantEnabled
                && root.providers.length > 0
                && !root.autoStartTried && !root.serviceStarting) {
            root.startService();
        } else {
            root.scheduleRecovery();
        }
    }

    function applyProviders(text) {
        const lines = (text || "").split("\n");
        const list = [];
        for (let i = 0; i < lines.length; ++i) {
            const name = lines[i].trim();
            if (name !== "" && list.indexOf(name) < 0)
                list.push(name);
        }
        root.providers = list;

        // Сохранённый выбор оставляем, если провайдеры ещё доступны.
        // Иначе по умолчанию — desktopapplications, либо первый доступный.
        if (root.enabledProviders.length > 0) {
            root.enabledProviders = root.validProviders(root.enabledProviders);
        }
        if (root.enabledProviders.length === 0 && list.length > 0) {
            const preferred = list.indexOf("desktopapplications") >= 0
                ? "desktopapplications" : list[0];
            root.enabledProviders = [preferred];
        }
        root.requestSearch();
    }

    // --- поиск ------------------------------------------------------------
    Connections {
        target: DockState

        function onQueryChanged() {
            root.setQuery(DockState.query);
        }

        function onExpandedChanged() {
            if (!DockState.expanded)
                return;
            if (root.providers.length === 0)
                root.refresh();
            else
                root.probeIfNeeded();
            root.requestSearch();
        }

        function onSettingsOpenChanged() {
            if (!DockState.settingsOpen)
                return;
            if (root.providers.length === 0)
                root.refresh();
            else
                root.probeIfNeeded();
        }
    }

    function setQuery(value) {
        root.query = String(value === undefined || value === null ? "" : value);
        root.requestSearch();
    }

    function requestSearch() {
        if (root.useBuiltin || !DockState.expanded) {
            root.loading = false;
            root.results = root.builtinResults();
            root.lastResultArg = "";
            root.scheduleRecovery();
            return;
        }
        root.loading = true;
        debounce.restart();
    }

    // Если сервис был доступен, но запрос сорвался, не остаёмся на
    // встроенном поиске до перезапуска панели: пробуем восстановиться.
    function scheduleRecovery() {
        if (!root.elephantEnabled || !root.installed || root.elephantAvailable
                || root.probing || root.serviceStarting)
            return;
        recovery.restart();
    }

    function builtinResults() {
        const needle = root.query.trim().toLowerCase();
        const list = [];
        const apps = DockApps.all;
        for (let i = 0; i < apps.length; ++i) {
            const entry = apps[i];
            const name = String(entry.name);
            if (needle !== "" && !name.toLowerCase().includes(needle))
                continue;
            list.push({
                key: "builtin:" + entry.id,
                provider: "builtin",
                identifier: entry.id,
                title: name,
                subtitle: "",
                icon: entry.icon || "",
                action: "start",
                qid: 0,
                entry: entry
            });
        }
        return list;
    }

    function parseElephant(text) {
        const lines = (text || "").split("\n");
        const list = [];
        let qid = 0;
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim();
            if (line === "")
                continue;
            let payload = null;
            try {
                payload = JSON.parse(line);
            } catch (error) {
                continue;
            }
            if (!payload || !payload.item)
                continue;
            const item = payload.item;
            if (payload.qid !== undefined)
                qid = Number(payload.qid);
            const provider = String(item.provider || "");
            const identifier = String(item.identifier || "");
            const actions = item.actions || [];
            list.push({
                key: provider + ":" + identifier,
                provider: provider,
                identifier: identifier,
                title: String(item.text || ""),
                subtitle: String(item.subtext || ""),
                icon: String(item.icon || ""),
                action: actions.length > 0 ? String(actions[0]) : "start",
                qid: qid,
                entry: null
            });
        }
        root.pendingResults = list;
        root.pendingQid = qid;
    }

    function activate(item) {
        if (!item)
            return;
        if (item.entry) {
            item.entry.execute();
            return;
        }
        if (item.qid <= 0 || item.provider === "")
            return;
        const query = root.query.replace(/[;\n\r]/g, " ").trim();
        root.activateArg = item.qid + ";" + item.provider + ";" + item.identifier
            + ";" + item.action + ";" + query;
        if (activateProc.running) {
            activateProc.running = false;
            startActivate.restart();
            return;
        }
        startActivate.restart();
    }
}
