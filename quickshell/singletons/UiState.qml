pragma Singleton

import QtQuick
import Quickshell

// Что и на каком экране открыто в попапе быстрых настроек.
// Отдельный синглтон, чтобы состоянием можно было управлять снаружи
// через `qs ipc call bar ...` (и, например, повесить на бинд в Hyprland).
Singleton {
    property string openedScreen: ""
    property string panel: ""

    readonly property bool opened: openedScreen !== ""

    function open(screenName, panelName) {
        openedScreen = screenName;
        panel = panelName;
    }

    function close() {
        openedScreen = "";
        panel = "";
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
