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
    // Множитель прокрутки списка приложений: 1.0 — один шаг как в остальных
    // списках оболочки, больше — быстрее, меньше — точнее.
    property real scrollFactor: 1.0
    // С какой стороны кнопка раскрытия: "left" или "right".
    property string buttonSide: "right"

    readonly property bool buttonOnLeft: root.buttonSide === "left"

    // Во время восстановления не пишем прочитанное обратно в файл.
    property bool restoring: false

    onIconSizeChanged: root.store("dock.iconSize", root.iconSize)
    onScrollFactorChanged: root.store("dock.scrollFactor", root.scrollFactor)
    onButtonSideChanged: root.store("dock.buttonSide", root.buttonSide)

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

    function setButtonSide(side) {
        root.buttonSide = side === "left" ? "left" : "right";
    }

    function reset() {
        root.setIconSize(Theme.dockIconSize);
        root.setScrollFactor(1.0);
        root.setButtonSide("right");
    }

    function restore() {
        root.restoring = true;
        root.setIconSize(Settings.value("dock.iconSize", root.iconSize));
        root.setScrollFactor(Settings.value("dock.scrollFactor", root.scrollFactor));
        root.setButtonSide(Settings.value("dock.buttonSide", root.buttonSide));
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
