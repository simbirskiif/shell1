pragma Singleton

import QtQuick
import Quickshell

// Состояние нижнего дока. Как и UiState, это отдельный синглтон: разметка
// только читает цели, а движением занимаются Behavior'ы в Dock.qml.
//
// Почему фазы, а не два булевых флага: док умеет появляться, раскрываться и
// прятаться одновременно. Таймер доводит переход до конца, поэтому раскрытие,
// вызванное у скрытого дока, не обрывает появление: карточка сначала выезжает
// компактной и только потом растёт в панель.
Singleton {
    id: root

    // phase: hidden | showing | compact | expanding | expanded | collapsing | hiding
    property string phase: "hidden"

    // Экран, на котором док активен. На остальных экранах видна только зона
    // активации; наведение переключает экран сюда.
    property string screenName: ""

    // Цели анимации. shown — карточка на экране, expanded — большой вид.
    property bool shown: false
    property bool expanded: false

    // Раскрытие, отложенное до конца появления: у скрытого дока сначала
    // выезжает компактная карточка, затем она плавно растёт.
    property bool pendingExpand: false

    // Док закреплён программно (IPC): по уходу курсора не прячем.
    // Клик по доку закрепления не даёт — панель остаётся временной.
    property bool holdOpen: false

    // Курсор над зоной активации или карточкой (пишет DockWindow).
    property bool hovered: false

    readonly property bool transitioning: root.phase === "showing"
                                        || root.phase === "expanding"
                                        || root.phase === "collapsing"
                                        || root.phase === "hiding"

    // Длительности совпадают с Behavior'ами карточки.
    readonly property int revealDuration: Theme.motionMedium2
    readonly property int morphDuration: Theme.motionLong1
    readonly property int hideDuration: Math.max(root.revealDuration, root.morphDuration)

    readonly property string summary: "phase=" + root.phase
        + " screen=" + (root.screenName === "" ? "-" : root.screenName)
        + " shown=" + root.shown
        + " expanded=" + root.expanded
        + " pending=" + root.pendingExpand
        + " hold=" + root.holdOpen
        + " hover=" + root.hovered

    // --- команды ----------------------------------------------------------

    // Компактный док, закреплённый на экране.
    function show(screenName) {
        if (screenName !== undefined && screenName !== "")
            root.screenName = screenName;
        root.holdOpen = true;
        root.pendingExpand = false;
        autoHide.stop();
        if (!root.shown) {
            root.shown = true;
            root.expanded = false;
            root.begin("showing", root.revealDuration);
        } else if (root.expanded) {
            root.expanded = false;
            root.begin("collapsing", root.morphDuration);
        } else if (root.phase !== "showing") {
            root.phase = "compact";
        }
    }

    // Большая панель. Из скрытого состояния раскрытие ждёт, пока карточка
    // выедет: иначе размер и появление стартовали бы в одном кадре и панель
    // «прыгала» бы вверх из-под края экрана.
    // pin=true — программное раскрытие (IPC): не прятать по уходу курсора.
    // Клик по доку оставляет панель «временной»: ушёл курсор — через
    // dockLingerExpanded она плавно уедет вниз.
    function expand(screenName, pin) {
        if (screenName !== undefined && screenName !== "")
            root.screenName = screenName;
        root.holdOpen = pin === true;
        autoHide.stop();
        if (!root.shown) {
            root.shown = true;
            root.expanded = false;
            root.pendingExpand = true;
            root.begin("showing", root.revealDuration);
            return;
        }
        // Второй вызов во время отложенного раскрытия не должен ломать
        // очередь: дождёмся конца появления.
        if (root.pendingExpand)
            return;
        if (root.expanded) {
            root.phase = "expanded";
            return;
        }
        root.expanded = true;
        root.begin("expanding", root.morphDuration);
    }

    // Вернуться к компактному доку (панель закрыта, док остаётся).
    function collapse() {
        root.holdOpen = false;
        autoHide.stop();
        root.pendingExpand = false;
        if (!root.expanded) {
            if (root.shown && !root.transitioning)
                root.maybeAutoHide();
            return;
        }
        root.expanded = false;
        if (!root.shown) {
            root.phase = "hidden";
            return;
        }
        root.begin("collapsing", root.morphDuration);
    }

    // Убрать док целиком: панель и карточка уезжают вниз одним движением.
    function hide() {
        root.holdOpen = false;
        root.pendingExpand = false;
        autoHide.stop();
        if (!root.shown) {
            root.expanded = false;
            root.phase = "hidden";
            return;
        }
        root.shown = false;
        root.expanded = false;
        root.begin("hiding", root.hideDuration);
    }

    // Переключение «панель/скрыть» для IPC и биндов.
    function toggle(screenName, pin) {
        if (root.shown && root.expanded)
            root.hide();
        else
            root.expand(screenName, pin);
    }

    // --- курсор -----------------------------------------------------------

    // Наведение на зону активации. На другом экране док переезжает туда
    // компактным: большая панель не должна «перескакивать» между мониторами.
    function pointerEntered(name) {
        root.hovered = true;
        autoHide.stop();
        if (root.screenName !== name) {
            root.screenName = name;
            root.holdOpen = false;
            root.expanded = false;
            root.pendingExpand = false;
            root.shown = true;
            root.begin("showing", root.revealDuration);
            return;
        }
        if (!root.shown) {
            root.shown = true;
            root.expanded = false;
            root.pendingExpand = false;
            root.begin("showing", root.revealDuration);
        }
    }

    function pointerExited() {
        root.hovered = false;
        root.maybeAutoHide();
    }

    function keepAlive() {
        autoHide.stop();
    }

    // --- переходы ---------------------------------------------------------

    function begin(name, duration) {
        root.phase = name;
        settle.interval = duration;
        settle.restart();
    }

    function finalize() {
        // Отложенное раскрытие — после появления.
        if (root.pendingExpand && root.shown) {
            root.pendingExpand = false;
            root.expanded = true;
            root.begin("expanding", root.morphDuration);
            return;
        }
        if (!root.shown) {
            root.expanded = false;
            root.phase = "hidden";
            return;
        }
        root.phase = root.expanded ? "expanded" : "compact";
        // Большая панель тоже может быть временной (клик по доку): если
        // курсор уже ушёл, запускаем долгий, но всё же уход. Для
        // программного раскрытия holdOpen=true отменяет таймер.
        root.maybeAutoHide();
    }

    function maybeAutoHide() {
        if (!root.shown || root.holdOpen || root.hovered)
            return;
        autoHide.interval = root.expanded ? Theme.dockLingerExpanded
                                               : Theme.dockLingerCompact;
        autoHide.restart();
    }

    // Доводчик перехода. Длительность равна анимации карточки; если цель
    // сменилась посреди движения, таймер перезапускается, а Behavior
    // продолжает с текущего значения — рывка нет.
    Timer {
        id: settle
        repeat: false
        onTriggered: root.finalize()
    }

    Timer {
        id: autoHide
        repeat: false
        onTriggered: root.hide()
    }
}
