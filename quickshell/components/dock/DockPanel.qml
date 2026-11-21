import QtQuick
import Quickshell
import ".."
import "../expressive"
import "../../singletons"

// Содержимое раскрытого дока: поиск, анимированный список приложений и
// настройки дока. Это «большая панель», в которую плавно превращается
// компактная полоса. Поверхность листа задаёт карточка дока (Dock.qml):
// в раскрытом виде она тонально опускается до surfaceContainerLow.
//
// Expressive: лист держит контрастные формы — точку-«печеньку» перед
// крупным заголовком typeEmphasizedHeadlineSmall, пилюлю-счётчик
// tertiary-контейнера и карточки приложений на разных контейнерах.
Item {
    id: root

    required property string screenName

    signal closeRequested()

    // Настройки открываются поверх списка, а не отдельным окном: панель уже
    // держит и маску ввода, и фокус-граб для закрытия по клику мимо.
    // Состояние в DockState, чтобы панель переживала пересоздание и
    // переключалась по IPC.
    readonly property bool settingsOpen: DockState.settingsOpen

    // Первый результат выбираем только на новом запросе, а не на каждом
    // обновлении выдачи: иначе асинхронный Elephant сбрасывает выбор,
    // сделанный стрелками.
    property bool selectFirstPending: false

    // Вид списка и его геометрия. Плитки — тот же ScriptModel, просто
    // другая сетка, поэтому фильтрация и переходы продолжают работать.
    readonly property bool tiles: DockSettings.tileLayout

    readonly property int columns: root.tiles ? Theme.dockGridColumns : 1
    // Строка списка — крупная воздушная пилюля: 60 внутри ячейки 64,
    // зазор 4 не даёт строкам слипаться без разделителей.
    readonly property real cellHeight: root.tiles ? Theme.dockGridCellHeight
                                                  : Theme.listItemHeight + Theme.space.sm
    readonly property real listContentHeight: {
        if (appList.count === 0)
            return 0;
        const rows = Math.ceil(appList.count / root.columns);
        return rows * root.cellHeight;
    }
    // Высота, которую хочет содержимое. В режиме «по списку» её использует
    // Dock: карточка плавно подстраивается под число строк.
    readonly property real desiredHeight: {
        // Даже с открытыми настройками окно следует за размером списка:
        // так включение режима «по списку» видно сразу, а не после
        // закрытия настроек. Сам блок настроек при этом прокручивается.
        const listPart = Math.max(72, root.listContentHeight);
        return header.height + Theme.space.sm + searchField.height
               + Theme.space.sm + listPart;
    }

    // Фокус в поле ставим явно, как только доку понадобилась клавиатура:
    // привязки focus мало, если поле ещё скрыто за кроссфейдом панели.
    Connections {
        target: DockState

        function onKeyboardActiveChanged() {
            if (DockState.keyboardActive)
                Qt.callLater(() => searchField.focusInput());
        }
    }

    // Накопленный оверскролл за верхним краем списка. Когда его достаточно,
    // панель закрывается — как «потянуть меню вверх».
    property real overscroll: 0

    // Физика колеса: колесо двигает цель, а contentY догоняет её
    // критически задемпфированной пружиной. Так шаг прокрутки плавный,
    // а не прыгает на N пикселей за кадр.
    property real scrollTarget: 0
    property real scrollVelocity: 0

    function maxScroll() {
        return Math.max(0, appList.contentHeight - appList.height);
    }

    function resetScroll() {
        scrollPhysics.stop();
        root.scrollTarget = 0;
        root.scrollVelocity = 0;
        if (appList.contentY !== 0)
            appList.contentY = 0;
    }

    function clampScroll() {
        const max = root.maxScroll();
        if (root.scrollTarget > max)
            root.scrollTarget = max;
        if (appList.contentY > max) {
            appList.contentY = max;
            root.scrollVelocity = 0;
        }
    }

    function applyWheelDelta(dy) {
        if (appList.moving) {
            // Нативный флик/тач: не боремся с ним.
            root.scrollTarget = appList.contentY;
            root.scrollVelocity = 0;
        }

        let target = scrollPhysics.running ? root.scrollTarget : appList.contentY;
        if (appList.contentY <= 0.5 && target <= 0.5 && dy > 0) {
            root.overscroll += dy;
            if (root.overscroll >= Theme.dockOverscrollClose) {
                root.overscroll = 0;
                overscrollReset.stop();
                DockState.hide();
            } else {
                overscrollReset.restart();
            }
            return;
        }

        root.overscroll = 0;
        overscrollReset.stop();
        target = Math.max(0, Math.min(root.maxScroll(),
            target - dy * DockSettings.scrollFactor));
        root.scrollTarget = target;
        if (!scrollPhysics.running)
            scrollPhysics.start();
    }

    function stepScroll() {
        if (appList.moving) {
            root.scrollTarget = appList.contentY;
            root.scrollVelocity = 0;
            scrollPhysics.stop();
            return;
        }

        root.scrollTarget = Math.max(0, Math.min(root.maxScroll(), root.scrollTarget));
        const dt = scrollPhysics.interval;
        const omega = Theme.dockScrollOmega;
        const a = appList.contentY - root.scrollTarget;
        const b = root.scrollVelocity + omega * a;
        const decay = Math.exp(-omega * dt);
        const path = a + b * dt;
        appList.contentY = Math.max(0, Math.min(root.maxScroll(),
            root.scrollTarget + path * decay));
        root.scrollVelocity = (b - omega * path) * decay;

        if (Math.abs(appList.contentY - root.scrollTarget) < Theme.dockScrollStop
                && Math.abs(root.scrollVelocity) < 0.02) {
            appList.contentY = root.scrollTarget;
            root.scrollVelocity = 0;
            scrollPhysics.stop();
        }
    }

    Timer {
        id: scrollPhysics
        interval: 16
        repeat: true
        onTriggered: root.stepScroll()
    }

    onTilesChanged: {
        root.resetScroll();
        if (appList.currentIndex >= 0)
            appList.positionViewAtIndex(appList.currentIndex, GridView.Contain);
    }

    // Отфильтрованный список. ScriptModel сравнивает старый и новый массивы
    // и отправляет GridView точечные insert/remove/move, поэтому уцелевшие
    // делегаты не пересоздаются и переезжают анимацией displaced.
    ScriptModel {
        id: filtered
        objectProp: "key"
        values: DockSearch.results
    }

    // Синхронизация поля с внешним запросом (IPC/сброс при закрытии) и
    // фокус при раскрытии панели.
    Connections {
        target: DockState

        function onQueryChanged() {
            searchField.setText(DockState.query);
            root.resetScroll();
            DockState.mouseGuardUntil = Date.now() + 300;
            if (DockState.query === "") {
                root.selectFirstPending = false;
                appList.currentIndex = -1;
            } else {
                root.selectFirstPending = true;
                Qt.callLater(root.selectFirst);
            }
        }

        function onExpandedChanged() {
            if (DockState.expanded) {
                DockState.mouseGuardUntil = Date.now() + 360;
                if (!DockState.settingsOpen)
                    searchField.focusInput();
            }
        }

        function onSettingsOpenChanged() {
            if (DockState.expanded && !DockState.settingsOpen)
                searchField.focusInput();
        }

        function onShownChanged() {
            if (!DockState.shown)
                searchField.setText("");
        }

    }

    Connections {
        target: DockSearch

        function onResultsChanged() {
            DockState.mouseGuardUntil = Date.now() + 300;
            if (appList.count === 0) {
                appList.currentIndex = -1;
                root.selectFirstPending = false;
            } else if (root.selectFirstPending) {
                appList.currentIndex = 0;
                root.selectFirstPending = false;
            } else if (appList.currentIndex >= appList.count) {
                appList.currentIndex = appList.count - 1;
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: DockState.expanded

        onActivated: {
            if (DockState.settingsOpen) {
                DockState.settingsOpen = false;
                return;
            }
            if (DockState.query !== "") {
                DockState.query = "";
                return;
            }
            DockState.hide();
        }
    }

    // Шапка — M3 top app bar: крупный emphasized-заголовок с точкой-маркером,
    // пилюля-счётчик и круглые icon button справа. Остаётся на месте,
    // содержимое прокручивается.
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.appBarHeight

        // Маркер-«печенька»: секция/экран читается цветной формой, а не
        // мелкой подписью.
        MorphShape {
            id: titleDot
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            shape: "cookie"
            color: Theme.tertiary
        }

        Text {
            id: titleText
            anchors.left: titleDot.right
            anchors.leftMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            text: root.settingsOpen ? "Настройки дока" : "Приложения"
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedHeadlineSmall
        }

        // Счётчик приложений — пилюля tertiary-контейнера: цифра крупная,
        // но это метаданные, поэтому контрастнее заголовка, но тише.
        Item {
            id: countChip
            anchors.left: titleText.right
            anchors.leftMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            width: countText.implicitWidth + Theme.space.lg + Theme.space.xs
            height: 26
            visible: !root.settingsOpen

            MorphShape {
                anchors.fill: parent
                shape: "pill"
                modulation: 0.35
                color: Theme.tertiaryContainer
            }

            Text {
                id: countText
                anchors.centerIn: parent
                text: appList.count
                color: Theme.scheme.onTertiaryContainer
                font: Theme.typeEmphasizedLabelLarge
            }
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: header.verticalCenter
        spacing: 2

        DockIconButton {
            size: Theme.iconButtonSize
            glyphSize: Theme.iconSize.md
            icon: "\uf013"
            accented: root.settingsOpen

            onClicked: DockState.settingsOpen = !DockState.settingsOpen
        }

        DockIconButton {
            size: Theme.iconButtonSize
            glyphSize: Theme.iconSize.md
            icon: "\uf00d"

            onClicked: root.closeRequested()
        }
    }

    // --- строка поиска ----------------------------------------------------
    DockSearchField {
        id: searchField
        anchors.left: parent.left
        anchors.right: layoutButton.left
        anchors.rightMargin: Theme.space.sm
        // Позиция задаётся явно, а не парой top/bottom-якорей: смена
        // положения не должна оставлять второй якорь активным и растягивать
        // поле на всю панель.
        y: DockSettings.searchAtBottom ? parent.height - height
                                       : header.height + Theme.space.sm
        height: DockSettings.searchHeight
        opacity: root.settingsOpen ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity { SpringEffects {} }

        onEdited: value => DockState.query = value
        onNavigate: delta => root.moveSelection(delta)
        onMoveHorizontal: delta => root.moveHorizontal(delta)
        onSubmitted: root.activateCurrent()
    }

    // Переключатель вида: строки ⇄ плитки. Он справа от поля поиска,
    // поэтому поле при смене позиции/размера остаётся в одной строке с ним.
    DockIconButton {
        id: layoutButton
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: searchField.verticalCenter
        visible: !root.settingsOpen
        size: Theme.iconButtonSize
        glyphSize: Theme.iconSize.md
        icon: DockSettings.tileLayout ? "\uf00b" : "\uf00a"
        accented: DockSettings.tileLayout

        onClicked: {
            DockSettings.setTileLayout(!DockSettings.tileLayout);
            searchField.focusInput();
        }
    }

    function selectFirst() {
        // Результаты приходят асинхронно: пока список пуст, заявку не
        // снимаем, иначе Enter запускал случайное приложение из старого
        // выделения.
        if (!root.selectFirstPending || appList.count === 0)
            return;
        root.selectFirstPending = false;
        if (DockState.query !== "")
            appList.currentIndex = 0;
    }

    function moveSelection(delta) {
        if (appList.count === 0)
            return;
        // GridView не умеет incrementCurrentIndex/decrementCurrentIndex —
        // индексы двигаем сами. В плитках шаг по строке, в списке по одному.
        if (appList.currentIndex < 0) {
            appList.currentIndex = delta > 0 ? 0 : appList.count - 1;
        } else if (root.tiles) {
            const step = Theme.dockGridColumns;
            const target = appList.currentIndex + delta * step;
            if (target >= 0 && target < appList.count)
                appList.currentIndex = target;
        } else {
            appList.currentIndex = Math.max(0, Math.min(appList.count - 1,
                appList.currentIndex + delta));
        }
        appList.positionViewAtIndex(appList.currentIndex, GridView.Contain);
    }

    function moveHorizontal(delta) {
        if (appList.count === 0 || !root.tiles)
            return;
        appList.currentIndex = Math.max(0, Math.min(appList.count - 1,
            (appList.currentIndex < 0 ? 0 : appList.currentIndex) + delta));
        appList.positionViewAtIndex(appList.currentIndex, GridView.Contain);
    }

    function activateCurrent() {
        const current = appList.currentItem;
        const item = current ? current : appList.itemAtIndex(0);
        if (!item)
            return;
        item.activate();
        DockState.hide();
    }

    // --- список приложений ------------------------------------------------
    // Подсветку выбора рисует сам DockListItem: форма (cookie/clover) и
    // контейнер важнее отдельного прямоугольника, который едет за курсором.
    GridView {
        id: appList
        anchors.left: parent.left
        anchors.right: parent.right
        y: DockSettings.searchAtBottom
           ? header.height + Theme.space.sm
           : searchField.y + searchField.height + Theme.space.sm
        height: DockSettings.searchAtBottom
                ? searchField.y - Theme.space.sm - y
                : parent.height - y
        clip: true
        focus: false
        activeFocusOnTab: false
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: root.tiles ? width / Theme.dockGridColumns : width
        cellHeight: root.cellHeight
        model: filtered
        currentIndex: -1
        // Первый элемент выбираем, как только модель наполнилась: выдача
        // приходит после смены запроса, и один callLater может не успеть.
        onCountChanged: {
            if (root.selectFirstPending && count > 0) {
                root.selectFirstPending = false;
                currentIndex = 0;
                positionViewAtIndex(0, GridView.Contain);
            }
        }
        onHeightChanged: root.clampScroll()
        onContentHeightChanged: root.clampScroll()
        enabled: !root.settingsOpen
        opacity: root.settingsOpen ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity { SpringEffects {} }

        delegate: DockListItem {
            id: dockItem

            required property var modelData

            item: modelData
            tile: root.tiles
            slot: dockItem.index
        }

        // Удаляемый элемент остаётся видимым до конца перехода: GridView
        // сам держит его в сцене, поэтому opacity/scale анимируем явно.
        remove: Transition {
            ParallelAnimation {
                MotionNumber {
                    property: "opacity"
                    to: 0
                }
                MotionNumber {
                    property: "scale"
                    to: Theme.motionElementScale
                }
            }
        }

        add: Transition {
            ParallelAnimation {
                MotionNumber {
                    property: "opacity"
                    from: 0
                    to: 1
                }
                MotionNumber {
                    property: "scale"
                    from: Theme.motionElementScale
                    to: 1
                }
            }
        }

        // Соседи переезжают на освободившиеся места на пружине:
        // в плитках двигаются и x, и y.
        displaced: Transition {
            ParallelAnimation {
                MotionNumber { property: "x" }
                MotionNumber { property: "y" }
            }
        }

        addDisplaced: Transition {
            ParallelAnimation {
                MotionNumber { property: "x" }
                MotionNumber { property: "y" }
            }
        }

        removeDisplaced: Transition {
            ParallelAnimation {
                MotionNumber { property: "x" }
                MotionNumber { property: "y" }
            }
        }
    }

    // Свой обработчик колеса: у GridView нет настройки чувствительности,
    // а оверскролл вверх должен закрывать панель. Слой прозрачен для кликов
    // и касаний — они уходят строкам под ним.
    Item {
        id: listOverlay
        anchors.fill: appList
        visible: !root.settingsOpen

        // «Мышь — второй приоритет»: выделение от указателя включается
        // только после реального движения. Панель может появиться под
        // неподвижным курсором — это не повод сбивать выбор с клавиатуры.
        WheelHandler {
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            orientation: Qt.Vertical

            onWheel: (event) => {
                const dy = event.pixelDelta.y !== 0
                    ? event.pixelDelta.y
                    : event.angleDelta.y * 0.5;
                if (dy === 0)
                    return;
                root.applyWheelDelta(dy);
                event.accepted = true;
            }
        }

        Timer {
            id: overscrollReset
            interval: 220
            onTriggered: root.overscroll = 0
        }
    }

    Text {
        anchors.centerIn: appList
        visible: !root.settingsOpen && appList.count === 0
        text: DockState.query !== "" ? "Ничего не найдено" : "Список приложений пуст"
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeTitleMedium
    }

    // --- настройки дока ---------------------------------------------------
    DockPanelSettings {
        anchors.top: header.bottom
        anchors.topMargin: Theme.space.sm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        enabled: root.settingsOpen
        opacity: root.settingsOpen ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity { SpringEffects {} }
    }
}
