pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Alt+Tab state, driven by Hyprland global shortcuts (Quickshell.Hyprland).
//
// Binds send altTabNext/altTabPrev on press and altTabRelease on Alt release.
// The overlay never takes keyboard focus, so the compositor keeps delivering
// the chord; no Keys.onReleased hacks or modifier polling.
Singleton {
    id: root

    property bool active: false      // chord is held
    property bool shown: false       // overlay visible
    property int index: 0
    property var snapshot: []        // frozen window list for this chord
    property var windows: []         // MRU cache

    property int pendingDir: 0       // first chord step while list is loading
    property bool pendingRelease: false

    property bool busy: false
    property string lastError: ""
    property string pendingAddress: ""

    readonly property int showDelay: 120

    function step(dir) {
        if (!root.active) {
            if (root.windows.length < 2) {
                root.pendingDir = dir;
                root.refresh();
                return;
            }
            root.begin(root.windows.slice(), dir);
            return;
        }

        if (root.snapshot.length === 0)
            return;

        root.index = (root.index + dir + root.snapshot.length) % root.snapshot.length;
        showTimer.stop();
        root.shown = true;
    }

    function begin(list, dir) {
        root.snapshot = list;
        root.active = true;
        root.shown = false;
        root.index = dir > 0 ? 1 : list.length - 1;
        root.pendingDir = 0;
        root.pendingRelease = false;
        showTimer.restart();
    }

    // Alt released: focus snapshot[index]. If the release came before the
    // window list finished loading, switch as soon as it arrives — without
    // ever showing the overlay (quick Alt+Tab).
    function release() {
        if (!root.active) {
            if (root.pendingDir !== 0)
                root.pendingRelease = true;
            return;
        }

        showTimer.stop();
        const target = root.snapshot[root.index];
        root.active = false;
        root.shown = false;
        if (target)
            root.focusAddress(target.address);
        root.scheduleRefresh();
    }

    function cancel() {
        showTimer.stop();
        root.active = false;
        root.shown = false;
        root.index = 0;
        root.pendingDir = 0;
        root.pendingRelease = false;
    }

    function refresh() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    function scheduleRefresh() {
        refreshLater.restart();
    }

    function focusAddress(address) {
        if (!address || root.busy)
            return;
        root.busy = true;
        root.pendingAddress = address;
        focusTimer.restart();
    }

    function summary() {
        return "active=" + (root.active ? "yes" : "no")
            + " shown=" + (root.shown ? "yes" : "no")
            + " index=" + root.index
            + " windows=" + root.windows.length
            + " snapshot=" + root.snapshot.length
            + (root.busy ? " busy" : "")
            + (root.lastError !== "" ? " err=" + root.lastError : "");
    }

    Timer {
        id: showTimer

        interval: root.showDelay
        repeat: false
        onTriggered: if (root.active)
            root.shown = true
    }

    // Сначала прячем оверлей, затем ставим фокус: иначе layer-shell
    // возвращает фокус прежнему окну после dispatcher'а.
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

    Timer {
        id: refreshLater

        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    // Держим MRU-кэш свежим, пока chord не активен.
    Timer {
        id: idleRefresh

        interval: 1200
        repeat: true
        running: !root.active
        onTriggered: root.refresh()
    }

    Process {
        id: listProcess

        command: ["hyprctl", "clients", "-j"]
        running: true

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

                    if (!root.active && root.pendingRelease && root.pendingDir !== 0) {
                        const dir = root.pendingDir;
                        root.pendingDir = 0;
                        root.pendingRelease = false;
                        if (list.length >= 2) {
                            root.snapshot = list;
                            root.index = dir > 0 ? 1 : list.length - 1;
                            root.focusAddress(list[root.index].address);
                        }
                        return;
                    }

                    if (!root.active && root.pendingDir !== 0 && list.length >= 2) {
                        root.begin(list, root.pendingDir);
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
        }
    }
}
