import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Содержимое попапа. Один список дескрипторов создаёт и плитки, и дочерние
// виды: добавить панель = добавить запись.
// Набор и порядок плиток лежит в MockState; в режиме редактирования правится
// черновик, поэтому закрытие панели отбрасывает изменения.
Item {
    id: root

    readonly property string panel: UiState.panel
    readonly property bool editing: UiState.editing

    readonly property var panels: [bluetoothEntry, internetEntry, soundEntry, brightnessEntry, layoutEntry, dndEntry, caffeineEntry, batteryEntry, settingsEntry, soundOutputEntry, soundInputEntry]

    // Плитки, которыми управляет редактор.
    readonly property var tileEntries: [bluetoothEntry, internetEntry, soundEntry, dndEntry, caffeineEntry, brightnessEntry, layoutEntry]

    readonly property var shownKeys: root.editing ? UiState.draftVisible : MockState.visibleTiles
    readonly property var poolKeys: root.editing ? UiState.draftAvailable : MockState.availableTiles

    readonly property var shownEntries: root.entriesFor(root.shownKeys)
    readonly property var poolEntries: root.entriesFor(root.poolKeys)

    function entryFor(key) {
        for (let i = 0; i < root.panels.length; ++i) {
            if (root.panels[i].key === key)
                return root.panels[i];
        }
        return null;
    }

    function entriesFor(keys) {
        const result = [];
        for (let i = 0; i < keys.length; ++i) {
            const entry = root.entryFor(keys[i]);
            if (entry)
                result.push(entry);
        }
        return result;
    }

    function indexOfShown(key) {
        return root.shownKeys.indexOf(key);
    }

    function isShown(key) {
        return root.shownKeys.indexOf(key) >= 0;
    }

    // Последняя позиция плитки в сетке: убранная плитка гаснет на месте,
    // а не улетает в угол.
    property var tileSlots: ({})

    function slotOf(key) {
        const slot = root.tileSlots[key];
        return slot === undefined ? -1 : slot;
    }

    function refreshTileSlots() {
        const map = {};
        for (const key in root.tileSlots)
            map[key] = root.tileSlots[key];
        for (let i = 0; i < root.shownKeys.length; ++i)
            map[root.shownKeys[i]] = i;
        root.tileSlots = map;
    }

    onShownKeysChanged: root.refreshTileSlots()

    function poolIndex(key) {
        return root.poolKeys.indexOf(key);
    }

    // Последняя позиция плитки в пуле: без этого пришлось бы
    // самоссылаться на x/y, что дёргает биндинги каждый кадр.
    property var poolSlots: ({})

    function poolSlotOf(key) {
        const slot = root.poolSlots[key];
        return slot === undefined ? -1 : slot;
    }

    function refreshPoolSlots() {
        const map = {};
        for (const key in root.poolSlots)
            map[key] = root.poolSlots[key];
        for (let i = 0; i < root.poolKeys.length; ++i)
            map[root.poolKeys[i]] = i;
        root.poolSlots = map;
    }

    onPoolKeysChanged: root.refreshPoolSlots()

    Component.onCompleted: {
        root.refreshTileSlots();
        root.refreshPoolSlots();
    }

    // Редактор живёт в UiState — так им можно управлять и снаружи.
    function beginEdit() {
        UiState.beginEdit();
    }

    function saveEdit() {
        UiState.saveEdit();
    }

    function cancelEdit() {
        UiState.cancelEdit();
    }

    function hideTile(key) {
        UiState.hideTile(key);
    }

    function showTile(key) {
        UiState.showTile(key);
    }

    function moveTile(from, to) {
        UiState.moveTile(from, to);
    }

    implicitWidth: Theme.quickWidth

    // Высоты обоих участников жеста: сетки и открытой дочерней панели.
    readonly property real mainHeight: mainView.implicitHeight
    // Высота дочернего вида. Только что активированный вид ещё не разложен
    // и на кадр отдаёт заведомо неполную высоту (заголовок без списка) —
    // из-за этого карточка на переходе схлопывалась до ~120 px и тут же
    // раздувалась. Пока идёт переход, держим высоту не ниже сетки, а когда
    // новый вид разложился — плавно доводим карточку до его настоящей
    // высоты (короткие панели после перехода аккуратно поджимаются).
    // Высота дочернего вида. Только что активированный вид до раскладки
    // отдаёт высоту-заглушку (заголовок без списка, ~120 px), из-за чего
    // карточка на переходе схлопывалась и тут же раздувалась. Панелей ниже
    // 150 px не бывает, поэтому такую высоту считаем недомеренной и держим
    // карточку не ниже сетки; реальные короткие панели (профили) сюда не
    // попадают и аккуратно поджимаются до своего размера.
    readonly property real detailHeight: {
        if (!root.activeDetail)
            return root.mainHeight;
        const height = root.activeDetail.implicitHeight;
        return height < 150 ? Math.max(root.mainHeight, height) : height;
    }

    // Высота содержимого: без жеста — высота открытой панели, во время
    // жеста ею рулит палец — от панели к сетке и обратно.
    readonly property real contentHeight: {
        if (root.panel === "")
            return root.mainHeight;
        if (root.gestureTowardMain)
            return root.detailHeight + (root.mainHeight - root.detailHeight) * root.swipe;
        return root.detailHeight;
    }

    // Во время жеста окну нужен запас по высоте: если менять размер самой
    // поверхности каждый кадр, композитор столько же раз пересоздаёт буфер
    // и всё лагает. Запас фиксируем на старте жеста: при доводке panel
    // успевает стать пустым, и «живой» максимум схлопнулся бы прямо посреди
    // движения — окно прыгало бы вверх-вниз на ровном месте.
    property real gestureRoom: 0
    readonly property bool gestureSizing: root.gestureTowardMain

    implicitHeight: root.contentHeight

    // Состояние жеста живёт в UiState — им можно управлять и снаружи,
    // и оно общее с зоной жеста в баре.
    readonly property real swipe: UiState.swipe
    readonly property bool swipeActive: UiState.swipeActive

    // Ключ панели, которую уводит текущий жест, и запас высоты на его время.
    // Фиксируем на старте: во время доводки panel успевает стать пустым,
    // а вид ещё должен доехать до конца под управлением пальца.
    property string gestureKey: ""

    onSwipeActiveChanged: {
        if (root.swipeActive) {
            root.gestureKey = root.panel;
            root.gestureRoom = Math.max(root.mainHeight, root.detailHeight);
        }
    }

    // Жест идёт от дочерней панели к сетке плиток: в нём участвуют ровно
    // два вида — уходящая панель и сетка. Остальные панели трогать нельзя,
    // иначе они все разом всплывают поверх друг друга.
    readonly property bool gestureTowardMain: root.swipeActive && root.gestureKey !== ""

    // Двумя пальцами по панели — назад, за пальцем.
    // MouseArea, а не WheelHandler: клики в панели работают, значит этот путь
    // события точно получает. acceptedButtons: NoButton — клики пропускаем.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: 10

        onWheel: wheel => {
            // У тачпадов pixelDelta часто нулевой — берём angleDelta как есть.
            const dx = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x;
            const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;

            if (!root.swipeActive && Math.abs(dx) <= Math.abs(dy))
                return;
            if (dx === 0)
                return;
            wheel.accepted = true;
            UiState.swipeBy(dx, root.width);
        }
    }

    PanelView {
        id: mainView
        // Вид держит свою высоту, а не высоту контейнера: она во время жеста
        // едет за пальцем, а масштаб считается от центра вида. На «плывущей»
        // высоте центр уезжал, и контент при сжатии сползал по вертикали —
        // при увеличении почти незаметно, при сжатии бросалось в глаза.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: implicitHeight
        // Во время жеста сетка уже видна и приезжает справа. active от жеста
        // не зависит: раскрытие ведёт палец, а не переход между состояниями.
        active: root.panel === ""
        gesture: root.gestureTowardMain ? root.swipe : -1
        gestureShift: 1
        gestureDirection: UiState.swipeDirection

        Column {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Theme.quickTileSpacing

            // Шапка: спокойная кнопка настроек, заголовок, нейтральный
            // чип батареи. Никаких крупных FAB и цветных контейнеров —
            // Expressive остаётся в движении и типографике.
            Item {
                width: parent.width
                height: 52

                Rectangle {
                    id: settingsButton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: width / 2
                    color: settingsHover.containsMouse ? Theme.surfaceContainerHighest
                                                       : Theme.surfaceContainerHigh

                    Text {
                        anchors.centerIn: parent
                        text: "\uf013"
                        color: Theme.scheme.onSurface
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: settingsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsEntry.open()
                    }
                }

                Text {
                    anchors.left: settingsButton.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: batteryChip.left
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Быстрые настройки"
                    color: Theme.scheme.onSurface
                    font: Theme.typeEmphasizedTitleLarge
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: batteryChip
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PowerService.present
                    width: batteryRow.width + Theme.space.lg
                    height: 38
                    radius: height / 2
                    color: Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.outlineVariant

                    Row {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 6

                        BatteryIndicator {
                            anchors.verticalCenter: parent.verticalCenter
                            level: PowerService.level
                            charging: PowerService.charging
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: PowerService.level + "%"
                            color: Theme.scheme.onSurface
                            font: Theme.typeLabelLarge
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: batteryEntry.open()
                    }
                }
            }

            // Сетка плиток: позиции считаем сами, поэтому перестановка
            // анимируется Behavior'ами, а не пересозданием элементов.
            Item {
                id: grid
                width: parent.width

                readonly property int columns: 2
                readonly property real spacing: Theme.quickTileSpacing
                readonly property real cellWidth: (width - spacing) / columns
                readonly property real cellHeight: Theme.quickTileHeight
                readonly property int rows: Math.ceil(root.shownEntries.length / columns)
                readonly property real stepX: cellWidth + spacing
                readonly property real stepY: cellHeight + spacing

                implicitHeight: rows > 0 ? rows * stepY - spacing : 0

                Repeater {
                    model: root.tileEntries

                    delegate: QuickTile {
                        required property var modelData

                        width: grid.cellWidth
                        height: grid.cellHeight
                        order: root.slotOf(modelData.key)
                        shown: root.isShown(modelData.key)
                        columns: grid.columns
                        stepX: grid.stepX
                        stepY: grid.stepY
                        x: order >= 0 ? (order % grid.columns) * grid.stepX : 0
                        y: order >= 0 ? Math.floor(order / grid.columns) * grid.stepY : 0
                        visible: opacity > 0
                        opacity: shown ? 1 : 0

                        icon: modelData.icon
                        title: modelData.title
                        subtitle: modelData.subtitle
                        active: modelData.active
                        editable: root.editing
                        // Плитка «Wi-Fi»: в кружке живые деления сигнала.
                        wifiStatus: modelData.wifiTile === true
                        onToggled: modelData.toggle()
                        onExpandRequested: modelData.open()
                        onRemoveRequested: root.hideTile(modelData.key)
                        onReorderRequested: (from, to) => root.moveTile(from, to)
                    }
                }
            }

            // Управление редактором: tonal-кнопка m3 «изменить», либо
            // текcтовая «отмена» и залитая «сохранить» — все формы-пилюли.
            Item {
                width: parent.width
                height: 56

                // m3 tonal button: secondary-container + on-secondary-container,
                // hover — state layer поверх заливки.
                Rectangle {
                    id: editButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.editing
                    width: editRow.implicitWidth + Theme.space.xl * 2
                    height: 48
                    radius: Theme.shape.full
                    color: Theme.secondaryContainer
                    scale: editHover.pressed ? 0.93 : (editHover.containsMouse ? 1.04 : 1)
                    Behavior on scale { SpringSpatial {} }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(Theme.scheme.onSecondaryContainer,
                                                Theme.stateHover)
                        opacity: editHover.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                    }

                    Row {
                        id: editRow
                        anchors.centerIn: parent
                        spacing: Theme.space.sm

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf040"
                            color: Theme.scheme.onSecondaryContainer
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.sm
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Изменить"
                            color: Theme.scheme.onSecondaryContainer
                            font: Theme.typeEmphasizedLabelLarge
                        }
                    }

                    MouseArea {
                        id: editHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.beginEdit()
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.sm
                    visible: root.editing

                    // m3 text button: прозрачная, подпись primary.
                    Rectangle {
                        id: cancelButton
                        width: cancelLabel.implicitWidth + Theme.space.xl * 2
                        height: Theme.buttonHeight
                        radius: Theme.shape.full
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.stateLayer(Theme.primary, Theme.stateHover)
                            opacity: cancelHover.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Отмена"
                            color: Theme.primary
                            font: Theme.typeLabelLarge
                        }

                        MouseArea {
                            id: cancelHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelEdit()
                        }
                    }

                    // m3 filled button: primary + on-primary.
                    Rectangle {
                        id: saveButton
                        width: saveLabel.implicitWidth + Theme.space.xl * 2
                        height: Theme.buttonHeight
                        radius: Theme.shape.full
                        color: Theme.primary

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.stateLayer(Theme.scheme.onPrimary, Theme.stateHover)
                            opacity: saveHover.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            id: saveLabel
                            anchors.centerIn: parent
                            text: "Сохранить"
                            color: Theme.scheme.onPrimary
                            font: Theme.typeLabelLarge
                        }

                        MouseArea {
                            id: saveHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveEdit()
                        }
                    }
                }
            }

            // Пул доступных плиток — внизу в режиме редактирования.
            Column {
                width: parent.width
                spacing: 0
                visible: root.editing
                height: root.editing ? implicitHeight : 0

                PanelSection { text: "Available" }

                Text {
                    width: mainColumn.width
                    // Ровно высота ячейки пула: переход пул 0 <-> 1 вообще
                    // не меняет высоту панели, поэтому окно не дёргается.
                    // Условие своё, а не visible: visible гаснет и вместе
                    // со скрытым предком — тогда высота бы схлопнулась.
                    visible: root.poolEntries.length === 0
                    height: root.poolEntries.length === 0 ? Theme.quickTileHeight : 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "All tiles are on the panel"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }

                Item {
                    id: poolGrid
                    width: mainColumn.width

                    readonly property int columns: 2
                    readonly property real spacing: Theme.quickTileSpacing
                    readonly property real cellWidth: (width - spacing) / columns
                    readonly property real cellHeight: Theme.quickTileHeight
                    readonly property real stepX: cellWidth + spacing
                    readonly property real stepY: cellHeight + spacing
                    readonly property int rows: Math.ceil(root.poolKeys.length / columns)

                    implicitHeight: rows > 0 ? rows * stepY - spacing : 0

                    Repeater {
                        model: root.tileEntries

                        delegate: PoolTile {
                            required property var modelData

                            readonly property int poolOrder: root.poolIndex(modelData.key)
                            readonly property int poolSlot: root.poolSlotOf(modelData.key)

                            width: poolGrid.cellWidth
                            height: poolGrid.cellHeight
                            x: (poolSlot % poolGrid.columns) * poolGrid.stepX
                            y: Math.floor(poolSlot / poolGrid.columns) * poolGrid.stepY
                            visible: opacity > 0
                            opacity: poolOrder >= 0 ? 1 : 0
                            scale: poolOrder >= 0 ? 0.92 : Theme.motionElementScale * 0.92
                            shown: poolOrder >= 0

                            icon: modelData.icon
                            title: modelData.title
                            onAddRequested: root.showTile(modelData.key)
                        }
                    }
                }
            }
        }
    }

    Repeater {
        id: detailViews
        model: root.panels

        delegate: PanelView {
            required property var modelData

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: implicitHeight
            active: root.panel === modelData.key
            // Жест ведёт только та панель, которую уводим: у остальных
            // gesture остаётся -1, поэтому они не всплывают.
            gesture: (root.gestureTowardMain && root.gestureKey === modelData.key)
                     ? root.swipe : -1
            gestureShift: -1
            gestureDirection: UiState.swipeDirection

            Loader {
                id: viewLoader
                anchors.fill: parent
                sourceComponent: modelData.view
            }

            // Кнопка «назад» внутри панели возвращает к сетке плиток, а если
            // у панели задан backTo — к той панели, из которой её открыли
            // (например, из списка устройств обратно в «Звук»).
            Connections {
                target: viewLoader.item

                function onBackRequested() {
                    if (modelData.backTo !== undefined && modelData.backTo !== "")
                        UiState.openDetail(modelData.backTo);
                    else
                        UiState.closeDetail();
                }
            }
        }
    }

    // Единое описание панели: иконка, подписи, состояние, действия и
    // дочерний вид. Одна запись создаёт и плитку, и окно управления;
    // open() связывает плитку с её дочерним видом через ключ.
    QtObject {
        id: bluetoothEntry

        readonly property bool inGrid: true
        readonly property string key: "bluetooth"
        readonly property string title: "Bluetooth"
        readonly property string icon: "\uf293"
        readonly property bool active: BluetoothBackend.enabled
        readonly property string subtitle: BluetoothBackend.connectedSummary
        readonly property Component view: Component { PanelBluetooth {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            BluetoothBackend.toggleEnabled();
        }
    }

    QtObject {
        id: internetEntry

        readonly property bool inGrid: true
        readonly property string key: "internet"
        // Проводного соединения нет — плитка про Wi-Fi, и называться должна
        // так же; с подключённым проводом это уже «Internet».
        readonly property string title: NetworkService.internetViaEthernet ? "Internet" : "Wi-Fi"
        readonly property string icon: "\uf0ac"
        // С проводом — глобус, без провода — состояние Wi-Fi делениями.
        readonly property bool wifiTile: !NetworkService.internetViaEthernet
        // Плитка «включена» только при реальном подключении: сама по себе
        // включённая радиомодуляция ещё не интернет, и плитка не должна
        // гореть постоянно.
        readonly property bool active: NetworkService.wifiConnected || NetworkService.internetViaEthernet
        readonly property string subtitle: NetworkService.internetSummary
        readonly property Component view: Component { PanelInternet {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            NetworkService.toggleWifi();
        }
    }

    QtObject {
        id: soundEntry

        readonly property bool inGrid: true
        readonly property string key: "sound"
        readonly property string title: "Sound"
        readonly property string icon: AudioService.outputMuted ? "\uf026" : "\uf028"
        readonly property bool active: AudioService.available && !AudioService.outputMuted
        readonly property string subtitle: AudioService.outputSummary
        readonly property Component view: Component { PanelSound {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            AudioService.toggleOutputMute();
        }
    }

    // Выбор устройства вывода: не плитка, а отдельная панель, которую
    // открывает строка текущего устройства в панели «Звук». Кнопка «назад»
    // возвращает не в сетку, а обратно в «Звук» (backTo).
    QtObject {
        id: soundOutputEntry

        readonly property bool inGrid: false
        readonly property string key: "sound-output"
        readonly property string title: "Output device"
        readonly property string icon: "\uf028"
        readonly property bool active: false
        readonly property string subtitle: ""
        readonly property string backTo: "sound"
        readonly property Component view: Component { PanelAudioDevices { kind: "output" } }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // У списка устройств кружок ничего не переключает.
        }
    }

    QtObject {
        id: soundInputEntry

        readonly property bool inGrid: false
        readonly property string key: "sound-input"
        readonly property string title: "Input device"
        readonly property string icon: "\uf130"
        readonly property bool active: false
        readonly property string subtitle: ""
        readonly property string backTo: "sound"
        readonly property Component view: Component { PanelAudioDevices { kind: "input" } }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // У списка устройств кружок ничего не переключает.
        }
    }

    // «Не беспокоить»: история пишется, тосты не показываются. Отдельного
    // вида у плитки нет, поэтому и кружок, и вся площадь переключают режим.
    QtObject {
        id: dndEntry

        readonly property bool inGrid: true
        readonly property string key: "dnd"
        readonly property string title: "Не беспокоить"
        readonly property string icon: NotificationService.doNotDisturb ? "\uf1f6" : "\uf0f3"
        readonly property bool active: NotificationService.doNotDisturb
        readonly property string subtitle: NotificationService.doNotDisturb ? "Включено" : "Выключено"
        readonly property Component view: null

        function open() {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
        }

        function toggle() {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
        }
    }

    // Кофеин: кружок включает бесконечный режим, нажатие на остальную часть
    // открывает панель с выбором срока (30 минут, час, два, бесконечно).
    QtObject {
        id: caffeineEntry

        readonly property bool inGrid: true
        readonly property string key: "caffeine"
        readonly property string title: "Кофеин"
        readonly property string icon: "\uf0f4"
        readonly property bool active: CaffeineService.active
        readonly property string subtitle: CaffeineService.active
                                           ? CaffeineService.label : "Выключен"
        readonly property Component view: Component { PanelCaffeine {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            CaffeineService.toggle();
        }
    }

    // Яркость: плитка как у звука. Кружок слева ничего не делает,
    // нажатие на остальную часть открывает панель яркости.
    QtObject {
        id: brightnessEntry

        readonly property bool inGrid: true
        readonly property string key: "brightness"
        readonly property string title: "Brightness"
        readonly property string icon: "\uf185"
        readonly property bool active: BrightnessService.available
        readonly property string subtitle: BrightnessService.summary
        readonly property Component view: Component { PanelBrightness {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // У яркости кружок ничего не переключает.
        }
    }

    // Layout: переключает профиль Hyprland — scrolling, default и все,
    // что появится в ~/.config/hypr/profiles. Порядок берётся из каталога.
    QtObject {
        id: layoutEntry

        readonly property bool inGrid: true
        readonly property string key: "layout"
        readonly property string title: "Layout"
        readonly property string icon: "\uf00a"
        readonly property bool active: ProfileState.current !== ""
                                          && ProfileState.current !== "default"
        readonly property string subtitle: {
            const name = ProfileState.current;
            if (name === "")
                return "—";
            return name.charAt(0).toUpperCase() + name.slice(1);
        }
        readonly property Component view: Component { PanelLayout {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            ProfileState.next();
        }
    }

    // Настройки: тоже кнопка в шапке (слева от батареи), не плитка.
    QtObject {
        id: settingsEntry

        readonly property bool inGrid: false
        readonly property string key: "settings"
        readonly property string title: "Settings"
        readonly property string icon: "\uf013"
        readonly property bool active: false
        readonly property string subtitle: ""
        readonly property Component view: Component { PanelSettings {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // У настроек кружок ничего не переключает.
        }
    }

    // Батарея: не плитка, а кнопка в шапке основной панели,
    // но дочерний вид создаётся тем же механизмом.
    QtObject {
        id: batteryEntry

        readonly property bool inGrid: false
        readonly property string key: "battery"
        readonly property string title: "Battery"
        readonly property string icon: "\uf240"
        readonly property bool active: PowerService.charging
        readonly property string subtitle: PowerService.level + "%"
        readonly property Component view: Component { PanelBattery {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // Батарея не переключается: состояние приходит от UPower.
        }
    }
}
