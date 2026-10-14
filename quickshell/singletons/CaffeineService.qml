pragma Singleton

import QtQuick
import Quickshell

// Кофеин: не даём сессии уйти в простой — ни заставке, ни затемнению, ни сну.
//
// Ингибитор — нативный IdleInhibitor из Quickshell.Wayland. Сам он живёт в
// окне бара (протокол idle-inhibit привязывается к поверхности, поэтому
// window обязателен), а здесь только режим и срок его жизни.
//
// Режимы: "off", "30", "60", "120", "infinite". Кружок плитки сразу включает
// бесконечный, а срок выбирается в панели.
Singleton {
    id: root

    property string mode: "off"

    readonly property bool active: root.mode !== "off"
    readonly property string label: root.labelFor(root.mode)

    // Пункты меню панели: ключ и подпись в том же порядке, что и в панели.
    readonly property var modes: [
        { key: "off", title: "Выключен" },
        { key: "30", title: "30 минут" },
        { key: "60", title: "1 час" },
        { key: "120", title: "2 часа" },
        { key: "infinite", title: "Бесконечно" }
    ]

    // Сколько минут держать, 0 — бесконечно или выключено.
    readonly property int minutes: {
        if (root.mode === "30")
            return 30;
        if (root.mode === "60")
            return 60;
        if (root.mode === "120")
            return 120;
        return 0;
    }

    function labelFor(mode) {
        for (let i = 0; i < root.modes.length; ++i) {
            if (root.modes[i].key === mode)
                return root.modes[i].title;
        }
        return "";
    }

    function isMode(mode) {
        return mode === "off" || mode === "30" || mode === "60"
            || mode === "120" || mode === "infinite";
    }

    function setMode(mode) {
        if (!root.isMode(mode))
            return;
        root.mode = mode;
        expiry.stop();
        if (root.minutes > 0) {
            // Срок считаем от момента выбора, а не от включения режима:
            // переключение с 30 минут на час сбрасывает таймер.
            expiry.interval = root.minutes * 60000;
            expiry.start();
        }
    }

    // Кружок плитки: включить бесконечно, повторное нажатие — выключить.
    function toggle() {
        root.setMode(root.active ? "off" : "infinite");
    }

    Timer {
        id: expiry
        onTriggered: root.mode = "off"
    }
}
