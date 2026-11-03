pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Текущий tiling-layout Hyprland.
//
// hyprctl keyword в Lua-режиме недоступен, поэтому меняем через
// `hl.config` (hyprctl eval). Значение читаем из getoption и обновляем
// опросом: профиль может сменить layout сам.
Singleton {
    id: root

    readonly property var available: ["dwindle", "master", "scrolling"]
    property string current: "dwindle"

    readonly property string label: {
        if (root.current === "dwindle")
            return "Dwindle";
        if (root.current === "master")
            return "Master";
        if (root.current === "scrolling")
            return "Scrolling";
        return root.current || "—";
    }

    function refresh() {
        if (!queryProcess.running)
            queryProcess.running = true;
    }

    function setLayout(name) {
        if (root.available.indexOf(name) < 0)
            return;
        root.current = name;
        setProcess.command = ["hyprctl", "eval",
                              "hl.config({ general = { layout = \"" + name + "\" } })"];
        setProcess.running = true;
    }

    function cycle() {
        const at = root.available.indexOf(root.current);
        root.setLayout(root.available[(at + 1) % root.available.length]);
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: queryProcess

        command: ["hyprctl", "getoption", "general:layout", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text);
                    if (value && value.str)
                        root.current = value.str;
                } catch (error) {
                }
            }
        }

        stderr: StdioCollector {}
    }

    Process {
        id: setProcess

        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (code, status) => root.refresh()
    }
}
