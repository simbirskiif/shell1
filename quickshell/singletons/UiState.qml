pragma Singleton

import QtQuick
import Quickshell

// Что и на каком экране открыто в попапе быстрых настроек.
// Отдельный синглтон, чтобы состоянием можно было управлять снаружи
// через `qs ipc call bar ...` (и, например, повесить на бинд в Hyprland).
Singleton {
    id: root

    property string openedScreen: ""
    property string panel: ""

    // Режим редактирования плиток основной панели: правки идут в черновик
    // и применяются только по saveEdit().
    property bool editing: false

    // Текущая высота попапа — для отладки анимаций размера.
    property real popupHeight: 0

    // Экран, на котором открыт запрос пароля.
    property string dialogScreen: ""

    // --- жест «назад» двумя пальцами -----------------------------------
    // swipe: 0..1 — насколько вернулись назад (1 — снова сетка плиток).
    // Палец не двигает прогресс напрямую: за ним тянется пружина, поэтому
    // у жеста есть инерция, а у отпускания — «тяжёлая» доводка.
    property real swipe: 0
    property bool swipeActive: false
    // Направление жеста: +1 — вправо, -1 — влево. Определяется по первому
    // движению, поэтому знак прокрутки тачпада (natural scroll) не важен.
    property int swipeDirection: 1

    // Скорость пружины (прогресс за мс) и сглаженная скорость пальца.
    property real swipeVelocity: 0
    property real swipeFingerVelocity: 0
    // Куда тянет палец и куда доводим после отпускания.
    property real swipeTarget: 0
    property real swipeSettleTarget: 0
    property bool swipeSettling: false
    property real swipeSettleTime: 0
    property real swipeLastTime: 0

    // Чувствительность: полный прогресс — по 55% ширины с усилением 2.4,
    // то есть около 90 px на панели шириной 400 — жест делается лёгким
    // движением, а не размахом через пол-экрана.
    readonly property real swipeReach: 0.55
    readonly property real swipeGain: 2.4
    // Доводка: прогноз позиции через 80 мс перевалил за 0.4 — уходим назад.
    readonly property real swipeCommit: 0.4
    readonly property real swipeForecast: 80

    function swipeBy(delta, width) {
        if (panel === "" || width <= 0 || delta === 0)
            return;
        if (!swipeActive) {
            swipeActive = true;
            // Если доводка прошлого жеста уже закончилась, начинаем с нуля.
            if (swipe <= 0.001 || swipe >= 0.999)
                swipe = 0;
            swipeTarget = swipe;
            swipeVelocity = 0;
            swipeFingerVelocity = 0;
            swipeSettling = false;
            swipeDirection = delta > 0 ? 1 : -1;
            swipeLastTime = Date.now();
        }
        // Палец снова взялся за панель — доводку прекращаем и продолжаем
        // жест с текущего места.
        if (swipeSettling) {
            swipeSettling = false;
            swipeTarget = swipe;
        }

        const now = Date.now();
        const dt = Math.max(1, Math.min(64, now - swipeLastTime));
        swipeLastTime = now;

        // Шаг за одно событие ограничен: у колеса мыши одно деление — 120
        // единиц, без ограничения оно закрывало бы панель одним щелчком.
        const step = Math.max(-0.15, Math.min(0.15,
            delta * swipeDirection * swipeGain / (width * swipeReach)));
        swipeTarget = Math.max(-0.12, Math.min(1.12, swipeTarget + step));

        // Скорость пальца нужна для инерции на отпускании.
        const raw = Math.max(-0.02, Math.min(0.02, step / dt));
        swipeFingerVelocity = 0.65 * swipeFingerVelocity + 0.35 * raw;

        swipeRelease.restart();
    }

    // У прокрутки нет события «конец жеста»: считаем его завершённым по
    // паузе между событиями. 250 мс читались как «палец отпустил, а панель
    // стоит и думает», а слишком короткая пауза обрывала бы медленный свайп,
    // если пользователь на мгновение замер с пальцами на тачпаде.
    Timer {
        id: swipeRelease
        interval: 110
        onTriggered: root.endSwipe()
    }

    // Пружина живёт отдельным тиком, поэтому движение не прерывается на
    // отпускании: скорость палец отдаёт пружине, и та едет дальше.
    Timer {
        id: swipePhysics
        interval: 16
        repeat: true
        running: root.swipeActive
        onTriggered: root.stepSwipe()
    }

    function stepSwipe() {
        const dt = swipePhysics.interval;
        const target = swipeSettling ? swipeSettleTarget : swipeTarget;
        // Пока палец на панели — следуем за ним почти вплотную (лёгкая
        // инерция, но без ощущения «залипания»), после отпускания ведём
        // «тяжелее»: быстрый старт и торможение.
        const omega = swipeSettling ? 0.019 : 0.055;
        // Точное решение критически задемпфированной пружины:
        //   x(t) = T + (a + b t) e^(-w t),  a = x0 - T,  b = v0 + w a
        // В отличие от численного шага оно устойчиво при любых w и dt.
        // «В лоб» шаг Эйлера при w*dt около единицы раскачивал прогресс:
        // вид начинал мигать на соседних кадрах.
        const a = swipe - target;
        const b = swipeVelocity + omega * a;
        const decay = Math.exp(-omega * dt);
        const path = a + b * dt;
        swipe = target + path * decay;
        swipeVelocity = (b - omega * path) * decay;

        if (swipe <= 0) {
            swipe = 0;
            if (swipeVelocity < 0)
                swipeVelocity = 0;
        } else if (swipe >= 1) {
            swipe = 1;
            if (swipeVelocity > 0)
                swipeVelocity = 0;
        }

        if (!swipeSettling)
            return;
        // Всегда доводим ровно до 0 или 1 (страховка по времени — на случай,
        // если пружина подошла к цели асимптотически).
        swipeSettleTime += dt;
        if ((Math.abs(swipeSettleTarget - swipe) < 0.01 && Math.abs(swipeVelocity) < 0.002)
                || swipeSettleTime > 600)
            root.finishSwipe();
    }

    function endSwipe() {
        if (!swipeActive || swipeSettling)
            return;
        // Прогноз: палец не только сдвинул панель, но и двигался — короткий
        // быстрый флик должен закрывать панель так же, как долгий сдвиг.
        const forecast = Math.max(-0.35, Math.min(0.35, swipeFingerVelocity * swipeForecast));
        const meaningful = swipe > 0.05 || Math.abs(swipeFingerVelocity) > 0.004;
        swipeSettleTarget = (meaningful && swipe + forecast > swipeCommit) ? 1 : 0;
        // Инерцию пальца отдаём пружине — движение продолжается без паузы.
        swipeVelocity = swipeFingerVelocity;
        swipeSettling = true;
        swipeSettleTime = 0;
    }

    // Доводка закончена: вид переключаем, пока жест ещё владеет обоими
    // видами — тогда передача эстафеты анимации перехода идёт без мигания.
    function finishSwipe() {
        const wentBack = swipeSettleTarget >= 0.5;
        if (wentBack && panel !== "")
            closeDetail();
        swipeActive = false;
        swipeSettling = false;
        swipeVelocity = 0;
        swipeFingerVelocity = 0;
        swipeTarget = 0;
        swipe = 0;
    }

    function clearSwipe() {
        swipeRelease.stop();
        swipe = 0;
        swipeActive = false;
        swipeSettling = false;
        swipeVelocity = 0;
        swipeFingerVelocity = 0;
        swipeTarget = 0;
    }
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
        clearSwipe();
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
