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

    // key — стабильный идентификатор раздела (он же IPC-аргумент), titleKey —
    // ключ строки в словаре I18n, icon — глиф в навигации окна. Подпись
    // переводится в момент отрисовки, поэтому смена языка не требует
    // пересобирать список.
    readonly property var sections: [
        { key: "bar", titleKey: "settings.section.bar", icon: "\uf0c9" },
        { key: "quick", titleKey: "settings.section.quick", icon: "\uf009" },
        { key: "dock", titleKey: "settings.section.dock", icon: "\uf108" },
        { key: "notifications", titleKey: "settings.section.notifications", icon: "\uf0f3" },
        { key: "caffeine", titleKey: "settings.section.caffeine", icon: "\uf0f4" },
        { key: "player", titleKey: "settings.section.player", icon: "\uf001" },
        { key: "widgets", titleKey: "settings.section.widgets", icon: "\uf1b2" },
        { key: "appearance", titleKey: "settings.section.appearance", icon: "\uf1fc" },
        { key: "language", titleKey: "settings.section.language", icon: "\uf0ac" }
    ]

    property bool opened: false
    // Экран, на котором открыто окно. Окно одно на всю сессию: открытие на
    // другом мониторе переводит его туда, а не создаёт второе.
    property string screenName: ""
    property string section: "bar"
    // Открытый диалог выбора иконки элемента бара. Пусто — диалог закрыт.
    property string iconEditorKey: ""

    // Живой пример блюра в окне настроек. Показывается при движении
    // ползунков «Сила размытия» / «Контраст карточек» и сам гаснет.
    property bool blurPreviewVisible: false

    function showBlurPreview() {
        root.blurPreviewVisible = true;
        blurPreviewTimer.restart();
    }

    Timer {
        id: blurPreviewTimer

        interval: 1600
        repeat: false
        onTriggered: root.blurPreviewVisible = false
    }

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
        root.blurPreviewVisible = false;
        blurPreviewTimer.stop();
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
