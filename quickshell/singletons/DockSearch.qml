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
    property bool probing: false
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
        + " probing=" + root.probing
        + " providers=" + (root.providers.length > 0 ? root.providers.join("|") : "-")
        + " enabled=" + (root.enabledProviders.length > 0 ? root.enabledProviders.join("|") : "-")
        + " builtin=" + root.useBuiltin
        + " results=" + root.results.length

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
            if (code !== 0)
                root.elephantLost("listproviders: " + code);
            else if (root.providers.length === 0)
                root.elephantLost("нет провайдеров");
            else
                root.probe();
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
            if (code !== 0) {
                root.elephantLost(root.lastError || ("probe: " + code));
                return;
            }
            root.elephantAvailable = true;
            root.lastError = "";
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
    Process {
        id: queryProc
        command: ["elephant", "query", "--json", root.elephantArg]
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
            if (root.aborting) {
                root.aborting = false;
                root.startElephant.restart();
                return;
            }
            if (code !== 0) {
                root.pendingResults = [];
                root.elephantLost(root.lastError || ("query: " + code));
                return;
            }
            root.elephantAvailable = true;
            root.loading = false;
            if (root.useBuiltin) {
                root.results = root.builtinResults();
                return;
            }
            root.results = root.pendingResults;
            root.lastQid = root.pendingQid;
        }
    }

    property var pendingResults: []
    property int pendingQid: 0
    property bool aborting: false

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

    Timer {
        id: startElephant
        interval: 0
        onTriggered: {
            if (root.useBuiltin || !DockState.expanded)
                return;
            root.aborting = false;
            root.loading = true;
            queryProc.running = true;
        }
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
    }

    // --- поиск ------------------------------------------------------------
    Connections {
        target: DockState

        function onQueryChanged() {
            root.setQuery(DockState.query);
        }

        function onExpandedChanged() {
            if (DockState.expanded) {
                root.probeIfNeeded();
                root.requestSearch();
            }
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
            return;
        }
        root.loading = true;
        debounce.restart();
    }

    function runElephant() {
        if (root.useBuiltin || !DockState.expanded)
            return;
        if (queryProc.running) {
            root.aborting = true;
            queryProc.running = false;
            return;
        }
        root.loading = true;
        queryProc.running = true;
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
