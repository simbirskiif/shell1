import QtQuick
import ".."
import "../../singletons"

// Содержимое попапа. Один список дескрипторов создаёт и плитки, и дочерние
// виды: добавить панель = добавить запись.
// Набор и порядок плиток лежит в MockState; в режиме редактирования правится
// черновик, поэтому закрытие панели отбрасывает изменения.
Item {
    id: root

    readonly property string panel: UiState.panel
    readonly property bool editing: UiState.editing

    readonly property var panels: [bluetoothEntry, internetEntry, soundEntry, brightnessEntry, batteryEntry, settingsEntry]

    // Плитки, которыми управляет редактор.
    readonly property var tileEntries: [bluetoothEntry, internetEntry, soundEntry, brightnessEntry]

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

    readonly property Item activeDetail: {
        for (let i = 0; i < detailViews.count; ++i) {
            const view = detailViews.itemAt(i);
            if (view && view.active)
                return view;
        }
        return null;
    }

    implicitWidth: Theme.quickWidth
    implicitHeight: {
        // Высота следует за открытой панелью: во время жеста она не должна
        // прыгать на высоту сетки.
        if (root.panel === "")
            return mainView.implicitHeight;
        return root.activeDetail ? root.activeDetail.implicitHeight : mainView.implicitHeight;
    }

    // Состояние жеста живёт в UiState — им можно управлять и снаружи.
    readonly property real swipe: UiState.swipe
    readonly property bool swipeActive: UiState.swipeActive

    Connections {
        target: UiState

        function onSwipeCommandChanged() {
            if (UiState.swipeCommand === 1)
                swipeCommit.start();
            else if (UiState.swipeCommand === -1)
                swipeCancel.start();
        }
    }

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
            swipeEndTimer.restart();
        }
    }

    // Жест закончился (у скролла нет события «конец») — доводим или откатываем.
    Timer {
        id: swipeEndTimer
        // У скролла нет события «конец жеста»: считаем его завершённым
        // по паузе между событиями. 140 мс обрывали медленный свайп.
        interval: 250
        onTriggered: UiState.endSwipe()
    }

    Timer {
        id: swipeResetTimer
        interval: Theme.motionShort4 + 80
        onTriggered: UiState.clearSwipe()
    }

    MotionNumber {
        id: swipeCommit
        target: UiState
        property: "swipe"
        to: 1
        duration: Theme.motionMedium1
        curve: Theme.curveEmphasizedDecelerate
        onFinished: {
            UiState.closeDetail();
            swipeResetTimer.restart();
        }
    }

    MotionNumber {
        id: swipeCancel
        target: UiState
        property: "swipe"
        to: 0
        duration: Theme.motionShort4
        curve: Theme.curveEmphasized
        onFinished: UiState.clearSwipe()
    }

    PanelView {
        id: mainView
        anchors.fill: parent
        // Во время жеста сетка уже видна и приезжает справа.
        active: root.panel === "" || root.swipeActive
        gesture: root.swipeActive ? root.swipe : -1
        gestureShift: 1
        gestureDirection: UiState.swipeDirection

        Column {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Theme.quickTileSpacing

            // Шапка: настройки слева, батарея справа.
            Item {
                width: parent.width
                height: 36

                Rectangle {
                    id: settingsButton
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: width / 2
                    color: settingsHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf013"
                        color: Theme.quickText
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: settingsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsEntry.open()
                    }
                }

                BatteryButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    level: MockState.batteryLevel
                    charging: MockState.batteryCharging
                    onClicked: batteryEntry.open()
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
                        onToggled: modelData.toggle()
                        onExpandRequested: modelData.open()
                        onRemoveRequested: root.hideTile(modelData.key)
                        onReorderRequested: (from, to) => root.moveTile(from, to)
                    }
                }
            }

            // Управление редактором: карандаш, либо сохранить/отменить.
            Item {
                width: parent.width
                height: 40

                Rectangle {
                    id: editButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.editing
                    width: 32
                    height: 32
                    radius: width / 2
                    color: editHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf040"
                        color: Theme.quickText
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 14
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
                    spacing: 8
                    visible: root.editing

                    Rectangle {
                        id: cancelButton
                        width: 32
                        height: 32
                        radius: width / 2
                        color: cancelHover.hovered ? Theme.quickTileHover : Theme.quickTile
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            color: Theme.quickText
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: cancelHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelEdit()
                        }
                    }

                    Rectangle {
                        id: saveButton
                        width: 32
                        height: 32
                        radius: width / 2
                        color: Theme.accent

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.quickIconOn
                            opacity: saveHover.hovered ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00c"
                            color: Theme.quickIconOn
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 13
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
                height: visible ? implicitHeight : 0

                PanelSection { text: "Available" }

                Text {
                    width: mainColumn.width
                    // Ровно высота ячейки пула: переход пул 0 <-> 1 вообще
                    // не меняет высоту панели, поэтому окно не дёргается.
                    height: visible ? Theme.quickTileHeight : 0
                    visible: root.poolEntries.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "All tiles are on the panel"
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
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

            anchors.fill: parent
            active: root.panel === modelData.key
            gesture: root.swipeActive ? root.swipe : -1
            gestureShift: -1
            gestureDirection: UiState.swipeDirection

            Loader {
                id: viewLoader
                anchors.fill: parent
                sourceComponent: modelData.view
            }

            // Кнопка «назад» внутри панели возвращает к сетке плиток.
            Connections {
                target: viewLoader.item

                function onBackRequested() {
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
        readonly property bool active: MockState.bluetoothEnabled
        readonly property string subtitle: MockState.bluetoothSummary
        readonly property Component view: Component { PanelBluetooth {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleBluetooth();
        }
    }

    QtObject {
        id: internetEntry

        readonly property bool inGrid: true
        readonly property string key: "internet"
        readonly property string title: "Internet"
        readonly property string icon: "\uf0ac"
        readonly property bool active: MockState.wifiEnabled || MockState.internetViaEthernet
        readonly property string subtitle: MockState.internetSummary
        readonly property Component view: Component { PanelInternet {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleWifi();
        }
    }

    QtObject {
        id: soundEntry

        readonly property bool inGrid: true
        readonly property string key: "sound"
        readonly property string title: "Sound"
        readonly property string icon: MockState.soundEnabled ? "\uf028" : "\uf026"
        readonly property bool active: MockState.soundEnabled
        readonly property string subtitle: MockState.soundSummary
        readonly property Component view: Component { PanelSound {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleSound();
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
        readonly property bool active: MockState.brightness > 0
        readonly property string subtitle: Math.round(MockState.brightness * 100) + "%"
        readonly property Component view: Component { PanelBrightness {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // У яркости кружок ничего не переключает.
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
        readonly property bool active: MockState.batteryCharging
        readonly property string subtitle: MockState.batteryLevel + "%"
        readonly property Component view: Component { PanelBattery {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleCharging();
        }
    }
}
