pragma Singleton

import QtQuick
import Quickshell

// Тестовые данные для панелей, у которых бэкенда ещё нет: Bluetooth.
// Сеть (Wi-Fi и Ethernet) переехала в NetworkService — реальный backend
// поверх NetworkManager, батарея и режимы питания — в PowerService (UPower
// и power-profiles-daemon), звук — в AudioService (PipeWire), яркость —
// в BrightnessService (backlight/logind и DDC/CI).
Singleton {
    id: root

    property bool bluetoothEnabled: true

    // Настройки оболочки.
    property bool showBatteryPercent: true

    // Набор плиток основной панели: видимые (в порядке) и доступные.
    // Меняется кнопкой «Сохранить» в режиме редактирования или сразу из
    // раздела «Быстрые настройки» общего окна настроек.
    readonly property var defaultVisibleTiles: ["bluetooth", "internet", "sound", "dnd", "caffeine", "brightness", "layout"]
    property var visibleTiles: ["bluetooth", "internet", "sound", "dnd", "caffeine", "brightness", "layout"]
    property var availableTiles: []

    // Порядок элементов в баре: порядок в модели = слева-направо.
    readonly property ListModel barItems: ListModel {
        ListElement { itemKey: "battery"; title: "Battery" }
        ListElement { itemKey: "notifications"; title: "Notifications" }
        ListElement { itemKey: "status"; title: "Quick settings" }
    }

    // Подписи элементов бара по ключу: из них собирается модель при
    // восстановлении порядка.
    readonly property var barItemTitles: ({
        "battery": "Battery",
        "notifications": "Notifications",
        "status": "Quick settings"
    })

    // --- сохранение настроек ------------------------------------------------
    // Значения живут здесь (к ним привязан интерфейс), а Settings хранит их
    // между запусками. Во время восстановления обратной записи не делаем.

    property bool restoring: false

    onVisibleTilesChanged: root.store("tiles.visible", visibleTiles)
    onAvailableTilesChanged: root.store("tiles.available", availableTiles)
    onShowBatteryPercentChanged: root.store("bar.showBatteryPercent", showBatteryPercent)

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

    function restore() {
        root.restoring = true;
        root.visibleTiles = Settings.value("tiles.visible", root.visibleTiles);
        root.availableTiles = Settings.value("tiles.available", root.availableTiles);
        root.showBatteryPercent = Settings.value("bar.showBatteryPercent", root.showBatteryPercent);
        root.restoreBarOrder(Settings.value("bar.items", []));
        root.restoring = false;
    }

    // Сохранённый порядок применяем к модели: незнакомые ключи отбрасываем,
    // пропавшие из настройки — дописываем в конец, чтобы элемент не исчез.
    function restoreBarOrder(saved) {
        if (!saved || saved.length === 0)
            return;
        const order = [];
        for (let i = 0; i < saved.length; ++i) {
            const key = String(saved[i]);
            if (root.barItemTitles[key] !== undefined && order.indexOf(key) < 0)
                order.push(key);
        }
        for (const key in root.barItemTitles) {
            if (order.indexOf(key) < 0)
                order.push(key);
        }
        root.barItems.clear();
        for (let i = 0; i < order.length; ++i)
            root.barItems.append({ itemKey: order[i], title: root.barItemTitles[order[i]] });
    }

    function storeBarOrder() {
        const order = [];
        for (let i = 0; i < root.barItems.count; ++i)
            order.push(root.barItems.get(i).itemKey);
        root.store("bar.items", order);
    }

    function moveBarItem(index, delta) {
        root.moveBarItemTo(index, index + delta);
    }

    function moveBarItemTo(from, to) {
        if (from === to || from < 0 || to < 0
                || from >= root.barItems.count || to >= root.barItems.count)
            return;
        root.barItems.move(from, to, 1);
        root.storeBarOrder();
    }

    // Первый элемент в конец — для проверки снаружи.
    function rotateBarItems() {
        if (root.barItems.count > 1) {
            root.barItems.move(0, root.barItems.count - 1, 1);
            root.storeBarOrder();
        }
    }

    // Плитки быстрых настроек: перестановка и скрытие/возврат. Порядок
    // в массиве = порядок в сетке, изменения сразу пишутся в Settings.
    function moveVisibleTile(key, delta) {
        const tiles = root.visibleTiles.slice();
        const from = tiles.indexOf(key);
        const to = from + delta;
        if (from < 0 || to < 0 || to >= tiles.length || delta === 0)
            return;
        const item = tiles.splice(from, 1)[0];
        tiles.splice(to, 0, item);
        root.visibleTiles = tiles;
    }

    function hideQuickTile(key) {
        const tiles = root.visibleTiles.slice();
        const index = tiles.indexOf(key);
        if (index < 0)
            return;
        tiles.splice(index, 1);
        root.visibleTiles = tiles;
        if (root.availableTiles.indexOf(key) < 0)
            root.availableTiles = root.availableTiles.concat([key]);
    }

    function showQuickTile(key) {
        if (root.visibleTiles.indexOf(key) >= 0)
            return;
        root.visibleTiles = root.visibleTiles.concat([key]);
        root.availableTiles = root.availableTiles.filter(item => item !== key);
    }

    function resetQuickTiles() {
        root.visibleTiles = root.defaultVisibleTiles.slice();
        root.availableTiles = [];
    }

    // Сброс раздела «Бар» из окна настроек: исходный порядок и процент
    // батареи включён — так оболочка выглядит на первом запуске.
    function resetBarSettings() {
        root.showBatteryPercent = true;
        const order = ["battery", "notifications", "status"];
        root.barItems.clear();
        for (let i = 0; i < order.length; ++i)
            root.barItems.append({ itemKey: order[i], title: root.barItemTitles[order[i]] });
        root.storeBarOrder();
    }

    // Яркость переехала в BrightnessService (backlight/logind и DDC/CI):
    // заглушки здесь больше нет.

    // Батарея и режимы питания переехали в PowerService (UPower и
    // power-profiles-daemon): заглушек здесь больше нет.

    // --- Bluetooth ---------------------------------------------------------
    readonly property ListModel bluetoothDevices: ListModel {
        ListElement { name: "Pixel 8"; icon: "\uf10b"; connected: false; connecting: false }
        ListElement { name: "Xbox Controller"; icon: "\uf11b"; connected: true; connecting: false }
        ListElement { name: "Keychron K3"; icon: "\uf11c"; connected: false; connecting: false }
        ListElement { name: "MX Master 3"; icon: "\uf245"; connected: false; connecting: false }
    }

    // Сохранённые (спаренные) устройства — заготовка под «мои устройства».
    readonly property ListModel savedBluetoothDevices: ListModel {
        ListElement { name: "AirPods Pro"; icon: "\uf025"; connected: true; connecting: false }
        ListElement { name: "Sony WH-1000XM4"; icon: "\uf025"; connected: false; connecting: false }
    }

    // Поиск устройств: пока идёт — в панели виден индикатор.
    property bool bluetoothScanning: false

    // Короткие подписи для плиток; пересчитываются в refresh().
    property string bluetoothSummary: ""

    function toggleBluetooth() {
        bluetoothEnabled = !bluetoothEnabled;
        refresh();
    }

    property string connectingDevice: ""
    property bool bluetoothDiscoverable: false

    function toggleDiscoverable() {
        bluetoothDiscoverable = !bluetoothDiscoverable;
    }

    function requestDevice(name) {
        const lists = [savedBluetoothDevices, bluetoothDevices];
        for (let l = 0; l < lists.length; ++l) {
            const list = lists[l];
            for (let i = 0; i < list.count; ++i) {
                if (list.get(i).name !== name)
                    continue;
                if (list.get(i).connected) {
                    list.setProperty(i, "connected", false);
                    refresh();
                    return;
                }
                root.connectingDevice = name;
                list.setProperty(i, "connecting", true);
                bluetoothConnectTimer.restart();
                return;
            }
        }
    }

    Timer {
        id: bluetoothConnectTimer
        interval: 1400
        onTriggered: {
            const lists = [savedBluetoothDevices, bluetoothDevices];
            for (let l = 0; l < lists.length; ++l) {
                const list = lists[l];
                for (let i = 0; i < list.count; ++i) {
                    if (list.get(i).name !== root.connectingDevice)
                        continue;
                    list.setProperty(i, "connected", true);
                    list.setProperty(i, "connecting", false);
                }
            }
            root.connectingDevice = "";
            refresh();
        }
    }

    // Поиск устройств: имитация асинхронного сканирования.
    function scanBluetooth() {
        if (!bluetoothEnabled || bluetoothScanning)
            return;
        bluetoothScanning = true;
        bluetoothScanTimer.restart();
    }

    Timer {
        id: bluetoothScanTimer
        interval: 1400
        onTriggered: root.bluetoothScanning = false
    }

    function refresh() {
        if (bluetoothEnabled) {
            // В плитке показываем только первое подключённое устройство:
            // полный список виден во внутренней панели.
            let first = "";
            const lists = [savedBluetoothDevices, bluetoothDevices];
            for (let l = 0; l < lists.length && first === ""; ++l) {
                const list = lists[l];
                for (let i = 0; i < list.count; ++i) {
                    const device = list.get(i);
                    if (device.connected) {
                        first = device.name;
                        break;
                    }
                }
            }
            bluetoothSummary = first !== "" ? first : "No devices";
        } else {
            bluetoothSummary = "Off";
        }
    }

    function addBluetoothDevice() {
        const index = bluetoothDevices.count + 1;
        bluetoothDevices.append({
            name: "Test Device " + index,
            icon: "\uf109",
            connected: false
        });
        refresh();
    }

    function removeBluetoothDevice() {
        if (bluetoothDevices.count === 0)
            return;
        bluetoothDevices.remove(bluetoothDevices.count - 1);
        refresh();
    }

    Component.onCompleted: {
        refresh();
        // Синглтон создаётся лениво: настройки могли прочитаться раньше нас.
        if (Settings.loaded)
            root.restore();
    }
}
