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
    readonly property int minSearchHeight: 28
    readonly property int maxSearchHeight: 52
    readonly property int minPanelHeight: 280
    readonly property int maxPanelHeightLimit: 480

    // Размер глифа (и, соответственно, кнопки) в компактной полосе.
    property int iconSize: Theme.dockIconSize
    // Множитель прокрутки списка приложений: 1.0 — один шаг как в остальных
    // списках оболочки, больше — быстрее, меньше — точнее.
    property real scrollFactor: 1.0
    // С какой стороны кнопка раскрытия: "left" или "right".
    property string buttonSide: "right"
    // Вид списка: false — строки, true — плитки.
    property bool tileLayout: false
    // Высота строки поиска и её положение в панели.
    property int searchHeight: 36
    property bool searchAtBottom: false
    // Максимальная высота раскрытой панели и режим «по содержимому».
    property int panelMaxHeight: Theme.dockPanelHeight
    property bool fitPanelToContent: false

    readonly property bool buttonOnLeft: root.buttonSide === "left"

    // Во время восстановления не пишем прочитанное обратно в файл.
    property bool restoring: false

    onIconSizeChanged: root.store("dock.iconSize", root.iconSize)
    onScrollFactorChanged: root.store("dock.scrollFactor", root.scrollFactor)
    onButtonSideChanged: root.store("dock.buttonSide", root.buttonSide)
    onTileLayoutChanged: root.store("dock.tileLayout", root.tileLayout)
    onSearchHeightChanged: root.store("dock.searchHeight", root.searchHeight)
    onSearchAtBottomChanged: root.store("dock.searchAtBottom", root.searchAtBottom)
    onPanelMaxHeightChanged: root.store("dock.panelMaxHeight", root.panelMaxHeight)
    onFitPanelToContentChanged: root.store("dock.fitPanel", root.fitPanelToContent)

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

    function setTileLayout(value) {
        root.tileLayout = value === true;
    }

    function setSearchHeight(value) {
        const v = Number(value);
        if (!isFinite(v))
            return;
        root.searchHeight = Math.round(Math.max(root.minSearchHeight,
                                                Math.min(root.maxSearchHeight, v)));
    }

    function setSearchAtBottom(value) {
        root.searchAtBottom = value === true;
    }

    function setPanelMaxHeight(value) {
        const v = Number(value);
        if (!isFinite(v))
            return;
        root.panelMaxHeight = Math.round(Math.max(root.minPanelHeight,
                                                  Math.min(root.maxPanelHeightLimit, v)));
    }

    function setFitPanelToContent(value) {
        root.fitPanelToContent = value === true;
    }

    function reset() {
        root.setIconSize(Theme.dockIconSize);
        root.setScrollFactor(1.0);
        root.setButtonSide("right");
        root.setTileLayout(false);
        root.setSearchHeight(36);
        root.setSearchAtBottom(false);
        root.setPanelMaxHeight(Theme.dockPanelHeight);
        root.setFitPanelToContent(false);
    }

    function restore() {
        root.restoring = true;
        root.setIconSize(Settings.value("dock.iconSize", root.iconSize));
        root.setScrollFactor(Settings.value("dock.scrollFactor", root.scrollFactor));
        root.setButtonSide(Settings.value("dock.buttonSide", root.buttonSide));
        root.setTileLayout(Settings.value("dock.tileLayout", root.tileLayout) === true);
        root.setSearchHeight(Settings.value("dock.searchHeight", root.searchHeight));
        root.setSearchAtBottom(Settings.value("dock.searchAtBottom", root.searchAtBottom) === true);
        root.setPanelMaxHeight(Settings.value("dock.panelMaxHeight", root.panelMaxHeight));
        root.setFitPanelToContent(Settings.value("dock.fitPanel", root.fitPanelToContent) === true);
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
