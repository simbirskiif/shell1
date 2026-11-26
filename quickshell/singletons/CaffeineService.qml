pragma Singleton

import QtQuick
import Quickshell

// Кофеин: не даём сессии уйти в простой — ни заставке, ни затемнению, ни сну.
//
// Ингибитор — нативный IdleInhibitor из Quickshell.Wayland. Сам он живёт в
// окне бара (протокол idle-inhibit привязывается к поверхности, поэтому
// window обязателен), а здесь режим, срок и список сроков.
//
// Кружок плитки включает последний выбранный режим (по умолчанию —
// бесконечный), повторное нажатие выключает. Сроки задаются строкой
// настроек, например "30, 1h, 2h 30m": число без единицы — минуты.
Singleton {
    id: root

    // Строка настройки сроков; разбирается в options.
    property string durations: "30, 1h, 2h"
    // Текущий режим: "off", "m<минуты>" или "infinite".
    property string mode: "off"
    // Последний выбранный режим — его включает кружок.
    property string lastMode: "infinite"
    // Когда конечный режим закончится (мс epoch, 0 — бесконечно/выключено).
    property double expiresAt: 0

    readonly property bool active: root.mode !== "off"

    // Пункты панели: сроки из настройки плюс бесконечный. Пункта «выключен»
    // здесь нет — выключение делает переключатель в шапке или кружок плитки.
    readonly property var options: {
        const list = [];
        const seen = ({});
        const tokens = String(root.durations === undefined ? "" : root.durations).split(",");
        for (let i = 0; i < tokens.length; ++i) {
            const minutes = root.parseDuration(tokens[i]);
            if (minutes <= 0 || seen[minutes] === true)
                continue;
            seen[minutes] = true;
            list.push({ key: "m" + minutes, title: root.formatMinutes(minutes), minutes: minutes });
        }
        if (list.length === 0) {
            // Настройку разобрать не удалось: оставляем рабочий набор, чтобы
            // панель не осталась с одной строкой «Бесконечно».
            const fallback = [30, 60, 120];
            for (let i = 0; i < fallback.length; ++i) {
                list.push({ key: "m" + fallback[i], title: root.formatMinutes(fallback[i]),
                            minutes: fallback[i] });
            }
        }
        list.push({ key: "infinite", title: I18n.tr("caffeine.infinite"), minutes: 0 });
        return list;
    }

    readonly property string label: {
        if (!root.active)
            return I18n.tr("caffeine.off");
        const minutes = root.minutesOf(root.mode);
        return minutes > 0 ? root.formatMinutes(minutes) : I18n.tr("caffeine.infinite");
    }

    // ───────────── разбор сроков ─────────────

    // "30" → 30, "1h" → 60, "1h 30m" → 90, "90m" → 90, "1,5h" → 90.
    // Понимаем и русские единицы: ч, час(а/ов), мин, м.
    function parseDuration(text) {
        const value = (text || "").trim().toLowerCase();
        if (value === "")
            return 0;
        const hours = ["h", "hr", "hour", "hours", "ч", "час", "часа", "часов"];
        const pattern = /(\d+(?:[.,]\d+)?)\s*([a-zа-я]+)?/g;
        let minutes = 0;
        let match = pattern.exec(value);
        while (match !== null) {
            const number = parseFloat(match[1].replace(",", "."));
            const unit = match[2] || "";
            if (!isNaN(number))
                minutes += hours.indexOf(unit) >= 0 ? number * 60 : number;
            match = pattern.exec(value);
        }
        const rounded = Math.round(minutes);
        // Меньше минуты и больше недели — явная опечатка, не берём.
        if (rounded < 1 || rounded > 10080)
            return 0;
        return rounded;
    }

    function formatMinutes(minutes) {
        const hours = Math.floor(minutes / 60);
        const rest = minutes % 60;
        const parts = [];
        if (hours > 0)
            parts.push(I18n.trn("caffeine.duration.hours", hours));
        if (rest > 0)
            parts.push(I18n.trn("caffeine.duration.minutes", rest));
        return parts.length > 0 ? parts.join(" ")
                                : I18n.trn("caffeine.duration.minutes", minutes);
    }

    function minutesOf(key) {
        const match = /^m(\d+)$/.exec(key || "");
        return match === null ? 0 : parseInt(match[1], 10);
    }

    function optionByKey(key) {
        for (let i = 0; i < root.options.length; ++i) {
            if (root.options[i].key === key)
                return root.options[i];
        }
        return null;
    }

    // ───────────── управление ─────────────

    function setMode(key) {
        if (key === "off") {
            root.applyMode("off", 0);
            return;
        }
        const option = root.optionByKey(key);
        if (option !== null)
            root.applyMode(option.key, option.minutes);
    }

    function applyMode(key, minutes) {
        root.mode = key;
        if (key !== "off")
            root.lastMode = key;
        expiry.stop();
        if (minutes > 0) {
            // Срок считаем от момента выбора: переключение с 30 минут на час
            // сбрасывает таймер.
            root.startCountdown(key, minutes * 60000);
        } else {
            root.expiresAt = 0;
        }
    }

    function startCountdown(key, milliseconds) {
        root.mode = key;
        root.expiresAt = Date.now() + milliseconds;
        expiry.stop();
        expiry.interval = Math.max(1000, milliseconds);
        expiry.start();
    }

    // Кружок плитки: последний выбранный режим, а если он пропал из настроек —
    // бесконечно. Повторное нажатие выключает.
    function toggle() {
        if (root.active) {
            root.setMode("off");
            return;
        }
        root.setMode(root.optionByKey(root.lastMode) !== null ? root.lastMode : "infinite");
    }

    Timer {
        id: expiry
        onTriggered: root.setMode("off")
    }

    // ───────────── настройки ─────────────

    property bool restoring: false

    onDurationsChanged: root.store("caffeine.durations", durations)
    onModeChanged: root.store("caffeine.mode", mode)
    onLastModeChanged: root.store("caffeine.lastMode", lastMode)
    onExpiresAtChanged: root.store("caffeine.expiresAt", expiresAt)

    function store(key, value) {
        if (root.restoring || !Settings.loaded)
            return;
        Settings.setValue(key, value);
    }

    Connections {
        target: Settings

        function onLoadedChanged() {
            if (Settings.loaded)
                root.restore();
        }
    }

    // Строку длительностей правит окно ввода (InputDialog) — попап не может
    // забрать клавиатурный фокус.
    Connections {
        target: UiState

        function onInputAccepted(target, text) {
            if (target === "caffeine.durations")
                root.durations = text;
        }
    }

    function restore() {
        root.restoring = true;
        root.durations = Settings.value("caffeine.durations", root.durations);
        root.lastMode = Settings.value("caffeine.lastMode", root.lastMode);
        const savedMode = String(Settings.value("caffeine.mode", "off"));
        const savedLeft = Number(Settings.value("caffeine.expiresAt", 0)) - Date.now();
        root.restoring = false;

        if (savedMode === "infinite") {
            root.applyMode("infinite", 0);
        } else if (root.minutesOf(savedMode) > 0) {
            // Конечный срок мог истечь, пока оболочка была перезапущена.
            if (savedLeft > 1000)
                root.startCountdown(savedMode, savedLeft);
            else
                root.applyMode("off", 0);
        }
    }

    // Синглтон создаётся лениво: к моменту его появления настройки могли уже
    // прочитаться, и тогда onLoadedChanged не придёт.
    Component.onCompleted: {
        if (Settings.loaded)
            root.restore();
    }
}
