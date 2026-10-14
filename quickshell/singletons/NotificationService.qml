pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Состояние уведомлений: активные тосты и история для Центра.
//
// D-Bus-сервер уведомлений живёт в shell.qml и присылает события сюда
// через add(): сервисные объекты с регистрацией (как Process у Bluetooth)
// не заводятся внутри синглтона. Историю держим своим списком, а не
// server.trackedNotifications, потому что нужен свой порядок — свежие
// сверху; из trackedNotifications только восстанавливаемся после reload.
Singleton {
    id: root

    // NotificationServer из shell.qml (см. attach()).
    property var server: null

    // Всплывающие тосты, свежие в начале списка.
    property var popups: []
    // История Центра уведомлений, свежие в начале списка.
    property var history: []
    // Критичные уведомления показываем даже в режиме «не беспокоить».
    property bool doNotDisturb: false
    // Открыт ли Центр уведомлений.
    property bool centerOpen: false
    // Сколько уведомлений пришло с момента последнего открытия Центра.
    property int unseen: 0

    readonly property int count: root.history.length
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

        // Пережившее перезагрузку оболочки уведомление заново тостом не
        // показываем — только возвращаем в историю.
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

        if (!root.doNotDisturb || notification.urgency === NotificationUrgency.Critical) {
            root.popups = [notification].concat(root.popups);
            root.unseen += 1;
        }
    }

    function remember(notification) {
        if (root.history.indexOf(notification) !== -1)
            return;
        notification.closed.connect(() => root.forget(notification));
        root.history = [notification].concat(root.history);
    }

    // Уведомление закрыто (приложением, таймаутом или нами).
    function forget(notification) {
        root.popups = root.popups.filter(n => n !== notification);
        root.history = root.history.filter(n => n !== notification);
    }

    // Смахнули тост: убираем только из активных, в истории оставляем.
    function dropPopup(notification) {
        root.popups = root.popups.filter(n => n !== notification);
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
        const items = root.history.slice();
        root.popups = [];
        root.history = [];
        root.unseen = 0;
        for (let i = 0; i < items.length; ++i)
            items[i].dismiss();
    }

    function toggleCenter() {
        root.centerOpen = !root.centerOpen;
        if (root.centerOpen)
            root.unseen = 0;
    }

    function closeCenter() {
        root.centerOpen = false;
    }

    // Строка состояния для IPC и отладки.
    function summary() {
        let last = "-";
        if (root.history.length > 0)
            last = (root.history[0].appName || "?") + ": " + (root.history[0].summary || "");
        return "count=" + root.history.length
            + " popups=" + root.popups.length
            + " unseen=" + root.unseen
            + " dnd=" + (root.doNotDisturb ? "on" : "off")
            + " center=" + (root.centerOpen ? "open" : "closed")
            + " last=" + last;
    }
}
