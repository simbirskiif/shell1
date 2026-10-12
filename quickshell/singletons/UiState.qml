pragma Singleton

import QtQuick
import Quickshell

// Что и на каком экране открыто в попапе быстрых настроек.
// Отдельный синглтон, чтобы состоянием можно было управлять снаружи
// через `qs ipc call bar ...` (и, например, повесить на бинд в Hyprland).
Singleton {
    property string openedScreen: ""
    property string panel: ""

    // Режим редактирования плиток основной панели: правки идут в черновик
    // и применяются только по saveEdit().
    property bool editing: false

    // Текущая высота попапа — для отладки анимаций размера.
    property real popupHeight: 0
    property var draftVisible: []
    property var draftAvailable: []

    function beginEdit() {
        draftVisible = MockState.visibleTiles.slice();
        draftAvailable = MockState.availableTiles.slice();
        editing = true;
    }

    function saveEdit() {
        MockState.visibleTiles = draftVisible.slice();
        MockState.availableTiles = draftAvailable.slice();
        editing = false;
    }

    function cancelEdit() {
        editing = false;
    }

    function hideTile(key) {
        const visible = draftVisible.slice();
        const index = visible.indexOf(key);
        if (index < 0)
            return;
        visible.splice(index, 1);
        draftVisible = visible;
        draftAvailable = draftAvailable.concat([key]);
    }

    function showTile(key) {
        const available = draftAvailable.slice();
        const index = available.indexOf(key);
        if (index < 0)
            return;
        available.splice(index, 1);
        draftAvailable = available;
        draftVisible = draftVisible.concat([key]);
    }

    function moveTile(from, to) {
        const visible = draftVisible.slice();
        if (from < 0 || from >= visible.length || from === to)
            return;
        const target = Math.max(0, Math.min(visible.length - 1, to));
        const item = visible.splice(from, 1)[0];
        visible.splice(target, 0, item);
        draftVisible = visible;
    }

    readonly property bool opened: openedScreen !== ""

    function open(screenName, panelName) {
        openedScreen = screenName;
        panel = panelName;
    }

    function close() {
        openedScreen = "";
        panel = "";
        // Правки плиток не сохраняются при закрытии панели.
        editing = false;
    }

    function toggle(screenName) {
        if (openedScreen === screenName)
            close();
        else
            open(screenName, "");
    }

    // Открыть/закрыть дочернюю панель, не трогая сам попап.
    // Через это связаны плитка в основной сетке и её дочерний вид.
    function openDetail(panelName) {
        panel = panelName;
    }

    function closeDetail() {
        panel = "";
    }

    // Экран по умолчанию для внешних команд — первый подключённый.
    function defaultScreen() {
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }
}
