pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Состояние панели плеера. Панель одна на сессию: открытие на другом
// мониторе переводит её туда.
Singleton {
    id: root

    property bool opened: false
    property string screenName: ""

    function screenOrFirst(name) {
        if (name !== undefined && name !== null && String(name).length > 0)
            return String(name);
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== "")
            return Hyprland.focusedMonitor.name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function open(screen) {
        if (UiState.openedScreen !== "")
            UiState.close();
        if (DockState.expanded)
            DockState.collapse();
        if (NotificationService.centerOpen)
            NotificationService.closeCenter();
        root.screenName = root.screenOrFirst(screen);
        root.opened = true;
    }

    function close() {
        root.opened = false;
    }

    function toggle(screen) {
        if (root.opened)
            root.close();
        else
            root.open(screen);
    }

    function summary() {
        return "opened=" + (root.opened ? "yes" : "no")
            + " screen=" + (root.screenName === "" ? "-" : root.screenName)
            + " spectrum=" + (SpectrumService.enabled ? "on" : "off")
            + " playing=" + (SpectrumService.playing ? "yes" : "no");
    }
}
