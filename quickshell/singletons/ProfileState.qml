pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Состояние профилей Hyprland.
//
// Источник истины — файл ~/.local/state/hypr-profile/current: его пишет
// hypr-profile после успешного hyprctl reload. Список профилей читается
// из каталога ~/.config/hypr/profiles (сам active.lua в список не входит).
// Переключение — только через hypr-profile, без hyprctl keyword bind.
Singleton {
    id: root

    readonly property string home: String(Quickshell.env("HOME") || "")
    readonly property string configDir: String(Quickshell.env("XDG_CONFIG_HOME")
                                             || (root.home + "/.config")) + "/hypr"
    readonly property string profilesDir: root.configDir + "/profiles"
    readonly property string stateDir: String(Quickshell.env("XDG_STATE_HOME")
                                           || (root.home + "/.local/state")) + "/hypr-profile"
    readonly property string statePath: root.stateDir + "/current"
    readonly property string scriptPath: root.home + "/.local/bin/hypr-profile"

    property string current: ""
    property var profiles: []
    property bool pickerOpen: false
    property bool busy: false
    property string lastError: ""

    function refresh() {
        stateFile.reload();
        listProcess.running = true;
    }

    function setOpen(value) {
        root.pickerOpen = value;
        if (value)
            root.refresh();
    }

    function toggle() {
        root.setOpen(!root.pickerOpen);
    }

    function close() {
        root.pickerOpen = false;
    }

    function switchTo(name) {
        if (root.busy || !name)
            return;
        root.busy = true;
        root.lastError = "";
        switchProcess.command = [root.scriptPath, name];
        switchProcess.running = true;
    }

    function next() {
        if (root.profiles.length === 0)
            return;
        const at = root.profiles.indexOf(root.current);
        root.switchTo(root.profiles[(at + 1) % root.profiles.length]);
    }

    function summary() {
        return "profile=" + (root.current || "-")
            + " profiles=" + root.profiles.join(",");
    }

    FileView {
        id: stateFile

        path: root.statePath
        watchChanges: true
        printErrors: false
        // Файла ещё нет — это нормальный первый запуск, а не ошибка.
        onLoadFailed: root.current = ""
        onTextChanged: root.current = stateFile.text().trim()
        onLoadedChanged: if (stateFile.loaded)
            root.current = stateFile.text().trim()
    }

    Process {
        id: listProcess

        // Только регулярные *.lua, без сгенерированного active.lua.
        command: ["find", root.profilesDir, "-maxdepth", "1", "-type", "f",
                  "-name", "*.lua", "!", "-name", "active.lua", "-printf", "%f\n"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim();
                    if (line.endsWith(".lua"))
                        names.push(line.substring(0, line.length - 4));
                }
                names.sort();
                root.profiles = names;
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: switchProcess

        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: switchErr
        }

        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) {
                root.lastError = switchErr.text.trim();
                if (root.lastError === "")
                    root.lastError = I18n.tr("switcher.commandFailed",
                                               { command: "hypr-profile", code: code });
            } else {
                root.lastError = "";
                root.pickerOpen = false;
            }
            root.refresh();
        }
    }
}
