pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Состояние уведомлений: активные тосты и история для Центра.
//
// D-Bus-сервер уведомлений живёт в shell.qml и присылает события сюда
// через add(): сервисные объекты с регистрацией (как Process у Bluetooth)
// не заводятся внутри синглтона.
//
// Списки — ListModel, а не JS-массив. При переприсваивании массива Repeater
// пересоздаёт ВСЕ карточки, и они заново проигрывают появление (стопка
// мигает). ListModel меняется поштучно: новая карточка выезжает одна,
// остальные плавно съезжают вниз, ничего не пересоздаётся.
Singleton {
    id: root

    // NotificationServer из shell.qml (см. attach()).
    property var server: null

    // Роль называется entry, чтобы не конфликтовать с property notification
    // самой карточки.
    readonly property ListModel popups: ListModel {}
    readonly property ListModel history: ListModel {}

    // Критичные уведомления показываем даже в режиме «не беспокоить».
    property bool doNotDisturb: false
    // Открыт ли Центр уведомлений.
    property bool centerOpen: false
    // Сколько уведомлений пришло с момента последнего открытия Центра.
    property int unseen: 0

    readonly property int count: root.history.count
    readonly property bool hasUnread: root.unseen > 0

    // Вызывается из shell.qml после создания сервера.
    function attach(server) {
        root.server = server;
        // Пережившие перезагрузку оболочки уведомления возвращаем в историю:
        // тостами их заново не показываем.
        const model = server ? server.trackedNotifications : null;
        const carried = model ? model.values : null;
        if (!carried)
            return;
        for (let i = 0; i < carried.length; ++i)
            root.remember(carried[i]);
    }

    // Новое уведомление от сервера.
    function add(notification) {
        if (!notification)
            return;

        // Пережившее перезагрузку уведомление заново тостом не показываем.
        if (notification.lastGeneration) {
            if (!notification.transient) {
                notification.tracked = true;
                root.remember(notification);
            }
            return;
        }

        // transient (громкость, яркость) в истории не оставляем, поэтому и
        // не просим сервер его удерживать.
        if (!notification.transient) {
            notification.tracked = true;
            root.remember(notification);
        }

        // Центр открыт — уведомление уходит прямо в него, без тоста.
        // «Не беспокоить»: тостов нет, но critical показываем всё равно.
        if (!root.centerOpen
            && (!root.doNotDisturb || notification.urgency === NotificationUrgency.Critical)) {
            root.popups.insert(0, { entry: notification });
            root.unseen += 1;
        }
    }

    function indexOf(model, notification) {
        for (let i = 0; i < model.count; ++i) {
            const entry = model.get(i).entry;
            if (entry === notification)
                return i;
        }
        return -1;
    }

    function remember(notification) {
        if (root.indexOf(root.history, notification) !== -1)
            return;
        notification.closed.connect(() => root.forget(notification));
        root.history.insert(0, { entry: notification });
    }

    // Уведомление закрыто (приложением, таймаутом или нами).
    function forget(notification) {
        let index = root.indexOf(root.popups, notification);
        if (index !== -1)
            root.popups.remove(index);
        index = root.indexOf(root.history, notification);
        if (index !== -1)
            root.history.remove(index);
    }

    // Смахнули тост: убираем только из активных, в истории оставляем.
    function dropPopup(notification) {
        const index = root.indexOf(root.popups, notification);
        if (index !== -1)
            root.popups.remove(index);
        // transient живёт только тостом — закрываем его насовсем.
        if (notification && notification.transient)
            notification.dismiss();
    }

    // Закрыть навсегда: свайп в Центре или крестик на карточке.
    function dismiss(notification) {
        if (!notification)
            return;
        root.forget(notification);
        notification.dismiss();
    }

    function clearHistory() {
        const items = [];
        for (let i = 0; i < root.history.count; ++i)
            items.push(root.history.get(i).entry);
        root.popups.clear();
        root.history.clear();
        root.unseen = 0;
        for (let i = 0; i < items.length; ++i)
            items[i].dismiss();
    }

    function openCenter() {
        if (root.centerOpen)
            return;
        root.centerOpen = true;
        // То, что висело тостами, теперь видно в Центре — убираем стопку,
        // чтобы она не перекрывала панель.
        root.popups.clear();
        root.unseen = 0;
    }

    function toggleCenter() {
        if (root.centerOpen)
            root.closeCenter();
        else
            root.openCenter();
    }

    function closeCenter() {
        root.centerOpen = false;
    }

    // Строка состояния для IPC и отладки.
    function summary() {
        let last = "-";
        if (root.history.count > 0) {
            const first = root.history.get(0).entry;
            if (first)
                last = (first.appName || "?") + ": " + (first.summary || "");
        }
        return "count=" + root.history.count
            + " popups=" + root.popups.count
            + " unseen=" + root.unseen
            + " dnd=" + (root.doNotDisturb ? "on" : "off")
            + " center=" + (root.centerOpen ? "open" : "closed")
            + " last=" + last;
    }
}
