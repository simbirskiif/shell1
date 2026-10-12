pragma Singleton

import QtQuick
import Quickshell

// Тестовые данные вместо реальных сервисов: бэкенда пока нет.
// Позже заменяется на Quickshell.Bluetooth, Quickshell.Networking
// и Quickshell.Services.Pipewire — интерфейс компонентов не меняется.
Singleton {
    id: root

    property bool bluetoothEnabled: true
    property bool wifiEnabled: true
    property bool soundEnabled: true
    property real volume: 0.65
    property string outputName: "Built-in Speakers"

    // Ethernet: если подключён, в панели «Интернет» над списком Wi-Fi
    // показывается подключённый модем / проводное соединение.
    property bool ethernetConnected: true
    property string ethernetName: "Ethernet"
    property string ethernetSpeed: "1 Gbit/s"

    // Поиск сетей и устройств: пока идёт — в панели виден индикатор.
    property bool wifiScanning: false
    property bool bluetoothScanning: false

    // Короткие подписи для плиток; пересчитываются в refresh().
    property string bluetoothSummary: ""
    property string wifiSummary: ""

    readonly property string internetSummary: {
        if (ethernetConnected)
            return ethernetName;
        if (!wifiEnabled)
            return "Off";
        return wifiSummary !== "" ? wifiSummary : "Not connected";
    }

    // Иконки — глифы JetBrainsMono Nerd Font.
    readonly property ListModel wifiNetworks: ListModel {
        ListElement { name: "Home_5G"; strength: 4; secured: true; connected: true }
        ListElement { name: "Home_2.4G"; strength: 3; secured: true; connected: false }
        ListElement { name: "Neighbour_5G"; strength: 2; secured: true; connected: false }
        ListElement { name: "Cafe_Guest"; strength: 1; secured: false; connected: false }
    }

    // Сохранённые сети: заготовка под «известные» сети вне зоны видимости.
    // strength 0 = уровень неизвестен.
    readonly property ListModel savedWifiNetworks: ListModel {
        ListElement { name: "Office_WiFi"; strength: 0; secured: true; connected: false }
        ListElement { name: "Phone_Hotspot"; strength: 0; secured: true; connected: false }
    }

    readonly property ListModel bluetoothDevices: ListModel {
        ListElement { name: "Pixel 8"; icon: "\uf10b"; connected: false }
        ListElement { name: "Xbox Controller"; icon: "\uf11b"; connected: true }
        ListElement { name: "Keychron K3"; icon: "\uf11c"; connected: false }
        ListElement { name: "MX Master 3"; icon: "\uf245"; connected: false }
    }

    // Сохранённые (спаренные) устройства — заготовка под «мои устройства».
    readonly property ListModel savedBluetoothDevices: ListModel {
        ListElement { name: "AirPods Pro"; icon: "\uf025"; connected: true }
        ListElement { name: "Sony WH-1000XM4"; icon: "\uf025"; connected: false }
    }

    readonly property string soundSummary: soundEnabled ? Math.round(volume * 100) + "%" : "Muted"

    function toggleBluetooth() {
        bluetoothEnabled = !bluetoothEnabled;
        refresh();
    }

    function toggleWifi() {
        wifiEnabled = !wifiEnabled;
        refresh();
    }

    function toggleSound() {
        soundEnabled = !soundEnabled;
    }

    function toggleDevice(index) {
        bluetoothDevices.setProperty(index, "connected", !bluetoothDevices.get(index).connected);
        refresh();
    }

    function toggleSavedDevice(index) {
        savedBluetoothDevices.setProperty(index, "connected", !savedBluetoothDevices.get(index).connected);
        refresh();
    }

    function selectWifi(index) {
        for (let i = 0; i < wifiNetworks.count; ++i)
            wifiNetworks.setProperty(i, "connected", i === index);
        for (let i = 0; i < savedWifiNetworks.count; ++i)
            savedWifiNetworks.setProperty(i, "connected", false);
        wifiEnabled = true;
        refresh();
    }

    function selectSavedWifi(index) {
        for (let i = 0; i < savedWifiNetworks.count; ++i)
            savedWifiNetworks.setProperty(i, "connected", i === index);
        for (let i = 0; i < wifiNetworks.count; ++i)
            wifiNetworks.setProperty(i, "connected", false);
        wifiEnabled = true;
        refresh();
    }

    // Поиск сетей/устройств: имитация асинхронного сканирования.
    function scanWifi() {
        if (!wifiEnabled || wifiScanning)
            return;
        wifiScanning = true;
        wifiScanTimer.restart();
    }

    function scanBluetooth() {
        if (!bluetoothEnabled || bluetoothScanning)
            return;
        bluetoothScanning = true;
        bluetoothScanTimer.restart();
    }

    Timer {
        id: wifiScanTimer
        interval: 1800
        onTriggered: root.wifiScanning = false
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

        if (wifiEnabled) {
            let name = "";
            const lists = [wifiNetworks, savedWifiNetworks];
            for (let l = 0; l < lists.length && name === ""; ++l) {
                const list = lists[l];
                for (let i = 0; i < list.count; ++i) {
                    const network = list.get(i);
                    if (network.connected) {
                        name = network.name;
                        break;
                    }
                }
            }
            wifiSummary = name !== "" ? name : "Not connected";
        } else {
            wifiSummary = "Off";
        }
    }

    // Демо-строки: нужны, чтобы посмотреть анимации появления/удаления
    // элементов списка (qs ipc call bar addWifi / removeWifi и т.д.).
    function addWifiNetwork() {
        const index = wifiNetworks.count + 1;
        wifiNetworks.append({
            name: "Test_Network_" + index,
            strength: 1 + (index % 4),
            secured: index % 2 === 0,
            connected: false
        });
        refresh();
    }

    function removeWifiNetwork() {
        if (wifiNetworks.count === 0)
            return;
        wifiNetworks.remove(wifiNetworks.count - 1);
        refresh();
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
