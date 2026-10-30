pragma Singleton

import QtQuick
import Quickshell

// Настройки дока, которые пользователь меняет прямо в раскрытой панели.
// Хранятся в общем settings.json (Settings), как и остальные настройки
// оболочки, поэтому переживают hot reload и перезапуск.
Singleton {
    id: root

    readonly property int minIconSize: 20
    readonly property int maxIconSize: 44
    readonly property real minScrollFactor: 0.4
    readonly property real maxScrollFactor: 2.5

    // Размер глифа (и, соответственно, кнопки) в компактной полосе.
    property int iconSize: Theme.dockIconSize
    // Множитель прокрутки сетки приложений: 1.0 — один шаг как в остальных
    // списках оболочки, больше — быстрее, меньше — точнее.
    property real scrollFactor: 1.0

    // Во время восстановления не пишем прочитанное обратно в файл.
    property bool restoring: false

    onIconSizeChanged: root.store("dock.iconSize", root.iconSize)
    onScrollFactorChanged: root.store("dock.scrollFactor", root.scrollFactor)

    function store(key, value) {
        if (root.restoring || !Settings.loaded)
            return;
        Settings.setValue(key, value);
    }

    function setIconSize(value) {
        const v = Number(value);
        if (!isFinite(v))
            return;
        root.iconSize = Math.round(Math.max(root.minIconSize,
                                           Math.min(root.maxIconSize, v)));
    }

    function setScrollFactor(value) {
        const v = Number(value);
        if (!isFinite(v))
            return;
        root.scrollFactor = Math.max(root.minScrollFactor,
                                     Math.min(root.maxScrollFactor, v));
    }

    function reset() {
        root.setIconSize(Theme.dockIconSize);
        root.setScrollFactor(1.0);
    }

    function restore() {
        root.restoring = true;
        root.setIconSize(Settings.value("dock.iconSize", root.iconSize));
        root.setScrollFactor(Settings.value("dock.scrollFactor", root.scrollFactor));
        root.restoring = false;
    }

    Connections {
        target: Settings

        function onLoadedChanged() {
            if (Settings.loaded)
                root.restore();
        }
    }

    Component.onCompleted: if (Settings.loaded) root.restore()
}
