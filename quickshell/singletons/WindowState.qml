pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Список открытых окон Hyprland для Alt+Tab.
//
// Окна читаются из `hyprctl clients -j` и сортируются по focusHistoryID:
// индекс 0 — активное окно, дальше — в порядке недавнего фокуса, как в
// Windows Alt+Tab. Фокус ставится Lua-диспетчером
// `hl.dsp.focus({ window = "address:..." })`.
Singleton {
    id: root

    property bool open: false
    property int cursor: 0
    // Сколько шагов накопить, пока список окон ещё читается.
    property int pendingDelta: 0
    // Alt отпустили раньше, чем пришёл список: активировать после загрузки.
    property bool pendingCommit: false

    property var windows: []
    property bool busy: false
    property string lastError: ""
    property string pendingAddress: ""
    // Защита от двойного шага: Tab может прийти и от compositor-бинда,
    // и из QML, когда оверлей забрал клавиатуру.
    property double lastStepAt: 0

    function refresh() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    // Alt+Tab: первый шаг открывает список и сразу выделяет следующее окно,
    // последующие шаги листают. Shift+Tab идёт назад.
    function cycle(delta) {
        const now = Date.now();
        if (root.open && now - root.lastStepAt < 60)
            return;
        root.lastStepAt = now;

        if (!root.open) {
            root.open = true;
            root.cursor = 0;
            root.pendingDelta = delta;
            root.pendingCommit = false;
            root.lastError = "";
            root.refresh();
            return;
        }
        if (root.windows.length === 0) {
            root.pendingDelta += delta;
            return;
        }
        root.move(delta);
    }

    // Отпускание Alt: перейти к выбранному окну и закрыть список.
    function commit() {
        if (!root.open)
            return;
        if (root.windows.length === 0) {
            // Список ещё читается — решим после загрузки; если он уже пуст,
            // закрываемся, иначе оверлей останется без окон.
            root.pendingCommit = listProcess.running;
            if (!root.pendingCommit)
                root.cancel();
            return;
        }
        root.activate();
    }

    // Esc или клик мимо: закрыть без смены фокуса.
    function cancel() {
        root.open = false;
        root.pendingDelta = 0;
        root.pendingCommit = false;
    }

    function toggle() {
        if (root.open)
            root.cancel();
        else
            root.cycle(1);
    }

    function show() {
        root.cursor = 0;
        root.pendingDelta = 0;
        root.pendingCommit = false;
        root.lastError = "";
        root.open = true;
        root.refresh();
    }

    function close() {
        root.cancel();
    }

    function move(delta) {
        if (root.windows.length === 0)
            return;
        root.cursor = (root.cursor + delta + root.windows.length) % root.windows.length;
    }

    function activate() {
        if (root.busy || root.cursor < 0 || root.cursor >= root.windows.length)
            return;
        root.pendingAddress = root.windows[root.cursor].address;
        root.busy = true;
        // Сначала отпускаем клавиатурный захват оверлея: иначе Hyprland
        // возвращает фокус прежнему окну уже после dispatcher'а.
        root.open = false;
        focusTimer.restart();
    }

    function summary() {
        return "open=" + (root.open ? "yes" : "no")
            + " windows=" + root.windows.length
            + " cursor=" + root.cursor
            + (root.busy ? " busy" : "")
            + (root.lastError !== "" ? " err=" + root.lastError : "");
    }

    // Небольшая пауза, чтобы layer-shell поверхность успела скрыться
    // и не вернуть фокус прежнему окну после dispatcher'а.
    Timer {
        id: focusTimer

        interval: 60
        repeat: false

        onTriggered: {
            focusProcess.command = ["hyprctl", "dispatch",
                                    "hl.dsp.focus({ window = \"address:" + root.pendingAddress + "\" })"];
            focusProcess.running = true;
        }
    }

    Process {
        id: listProcess

        command: ["hyprctl", "clients", "-j"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const clients = JSON.parse(text);
                    const list = [];
                    for (let i = 0; i < clients.length; ++i) {
                        const client = clients[i];
                        if (!client.mapped)
                            continue;
                        list.push({
                            address: client.address,
                            title: client.title || client.class || "окно",
                            appClass: client.class || client.initialClass || "",
                            workspace: client.workspace ? client.workspace.name : "",
                            history: client.focusHistoryID !== undefined ? client.focusHistoryID : 9999
                        });
                    }
                    list.sort((a, b) => a.history - b.history);
                    root.windows = list;

                    if (list.length > 0 && root.pendingDelta !== 0) {
                        const index = (root.pendingDelta % list.length + list.length) % list.length;
                        root.cursor = index;
                        root.pendingDelta = 0;
                    } else if (root.cursor >= list.length) {
                        root.cursor = 0;
                    }

                    if (root.pendingCommit) {
                        root.pendingCommit = false;
                        if (list.length > 0)
                            root.activate();
                        else
                            root.cancel();
                    }
                } catch (error) {
                    root.windows = [];
                    root.lastError = "не удалось прочитать список окон: " + error;
                }
            }
        }

        stderr: StdioCollector {}
    }

    Process {
        id: focusProcess

        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: focusErr
        }

        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) {
                root.lastError = focusErr.text.trim() || ("hyprctl завершился с кодом " + code);
                return;
            }
            root.lastError = "";
            root.open = false;
        }
    }
}
