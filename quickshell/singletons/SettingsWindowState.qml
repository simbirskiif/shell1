pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Состояние отдельного окна настроек оболочки.
//
// Раньше настройки жили в трёх разных местах: экран внутри быстрых настроек,
// экран внутри раскрытого дока и попап параметров виджетов на рабочем столе.
// Теперь всё это — разделы одного окна, а здесь хранится только то, какое
// окно открыто и какой раздел в нём выбран.
Singleton {
    id: root

    // key — стабильный идентификатор раздела (он же IPC-аргумент), title и
    // icon — то, что видно в навигации окна.
    readonly property var sections: [
        { key: "bar", title: "Бар", icon: "\uf0c9" },
        { key: "quick", title: "Быстрые настройки", icon: "\uf009" },
        { key: "dock", title: "Док", icon: "\uf108" },
        { key: "notifications", title: "Уведомления", icon: "\uf0f3" },
        { key: "caffeine", title: "Кофеин", icon: "\uf0f4" },
        { key: "player", title: "Плеер", icon: "\uf001" },
        { key: "widgets", title: "Виджеты", icon: "\uf1b2" },
        { key: "appearance", title: "Оформление", icon: "\uf1fc" }
    ]

    property bool opened: false
    // Экран, на котором открыто окно. Окно одно на всю сессию: открытие на
    // другом мониторе переводит его туда, а не создаёт второе.
    property string screenName: ""
    property string section: "bar"
    // Открытый диалог выбора иконки элемента бара. Пусто — диалог закрыт.
    property string iconEditorKey: ""

    function hasSection(key) {
        for (let i = 0; i < root.sections.length; ++i) {
            if (root.sections[i].key === key)
                return true;
        }
        return false;
    }

    function screenOrFirst(name) {
        if (name !== undefined && name !== null && String(name).length > 0)
            return String(name);
        // Без явного экрана открываем на том, где сейчас фокус: иначе на
        // многомониторной конфигурации окно уезжало бы на первый экран.
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== "")
            return Hyprland.focusedMonitor.name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    // Пустой section — сохранить текущий раздел (так ведёт себя шестерёнка
    // в быстрых настройках: она просто открывает окно).
    function show(sectionKey, screen) {
        if (sectionKey !== undefined && String(sectionKey).length > 0
                && root.hasSection(sectionKey))
            root.section = String(sectionKey);
        root.screenName = root.screenOrFirst(screen);
        root.iconEditorKey = "";
        // Окно забирает клавиатуру эксклюзивно. Попап и раскрытый док —
        // тоже отдельные поверхности с фокусом, поэтому закрываем их,
        // иначе композитор выбирает между ними наугад.
        if (UiState.openedScreen !== "")
            UiState.close();
        if (DockState.expanded)
            DockState.collapse();
        if (PlayerWindowState.opened)
            PlayerWindowState.close();
        root.opened = true;
    }

    function close() {
        root.iconEditorKey = "";
        root.opened = false;
    }

    function openIconEditor(key) {
        if (key !== undefined && String(key).length > 0)
            root.iconEditorKey = String(key);
    }

    function closeIconEditor() {
        root.iconEditorKey = "";
    }

    function toggle(sectionKey, screen) {
        if (root.opened && (sectionKey === undefined
                            || String(sectionKey).length === 0
                            || String(sectionKey) === root.section)) {
            root.close();
            return;
        }
        root.show(sectionKey, screen);
    }

    function setSection(sectionKey) {
        if (root.hasSection(sectionKey)) {
            root.section = sectionKey;
            root.iconEditorKey = "";
        }
    }

    function summary() {
        return "opened=" + (root.opened ? "yes" : "no")
            + " section=" + root.section
            + " iconEditor=" + (root.iconEditorKey === "" ? "-" : root.iconEditorKey)
            + " screen=" + (root.screenName === "" ? "-" : root.screenName);
    }
}
