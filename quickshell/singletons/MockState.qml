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
    // Меняется только кнопкой «Сохранить» в режиме редактирования.
    property var visibleTiles: ["bluetooth", "internet", "sound", "dnd", "caffeine", "brightness"]
    property var availableTiles: []

    // Порядок элементов в баре: порядок в модели = слева-направо.
    readonly property ListModel barItems: ListModel {
        ListElement { itemKey: "battery"; title: "Battery" }
        ListElement { itemKey: "notifications"; title: "Notifications" }
        ListElement { itemKey: "status"; title: "Quick settings" }
    }

    function moveBarItem(index, delta) {
        const target = index + delta;
        if (target < 0 || target >= barItems.count)
            return;
        barItems.move(index, target, 1);
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

    Component.onCompleted: refresh()
}
