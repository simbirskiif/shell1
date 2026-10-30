pragma Singleton

import QtQuick
import Quickshell

// Каталог приложений для дока: избранное для компактной полосы и весь
// список для раскрытой панели. Один экземпляр на оболочку, а не на монитор:
// DesktopEntries читает сотни .desktop-файлов, дублировать это незачем.
Singleton {
    id: root

    // Весь список, уже отфильтрованный и отсортированный.
    property var all: []
    // Избранное в порядке DockApps.favoriteIds.
    property var favorites: []

    // id — имя .desktop-файла без расширения (так их отдаёт Quickshell).
    readonly property var favoriteIds: [
        "google-chrome",
        "org.telegram.desktop",
        "kitty",
        "org.gnome.Nautilus",
        "com.microsoft.VSCode",
        "spotify",
        "org.gnome.Calculator",
        "org.gnome.Settings"
    ]

    function reload() {
        const entries = DesktopEntries.applications.values;
        if (!entries || entries.length === 0)
            return;

        const list = [];
        for (let i = 0; i < entries.length; ++i) {
            const entry = entries[i];
            if (!entry || entry.noDisplay || !entry.name)
                continue;
            if (!entry.command || entry.command.length === 0)
                continue;
            list.push(entry);
        }
        list.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        root.all = list;

        const favorite = [];
        for (let f = 0; f < root.favoriteIds.length; ++f) {
            const wanted = String(root.favoriteIds[f]).toLowerCase();
            for (let i = 0; i < list.length; ++i) {
                const id = String(list[i].id).toLowerCase();
                if (id === wanted || id === wanted + ".desktop") {
                    favorite.push(list[i]);
                    break;
                }
            }
        }
        root.favorites = favorite;
    }

    // DesktopEntries заполняется асинхронно. Основной путь — сигнал модели,
    // а таймер нужен только на случай, если список пуст к моменту старта.
    Timer {
        interval: 800
        repeat: true
        running: root.all.length === 0
        onTriggered: root.reload()
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            root.reload();
        }
    }

    Component.onCompleted: root.reload()
}
