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

    // Короткие подписи для плиток; пересчитываются в refresh().
    property string bluetoothSummary: ""
    property string wifiSummary: ""

    // Иконки — глифы JetBrainsMono Nerd Font.
    readonly property ListModel bluetoothDevices: ListModel {
        ListElement { name: "AirPods Pro"; icon: "\uf025"; connected: true }
        ListElement { name: "Keychron K3"; icon: "\uf11c"; connected: false }
        ListElement { name: "MX Master 3"; icon: "\uf245"; connected: true }
    }

    readonly property ListModel wifiNetworks: ListModel {
        ListElement { name: "Home_5G"; strength: 4; secured: true; connected: true }
        ListElement { name: "Home_2.4G"; strength: 3; secured: true; connected: false }
        ListElement { name: "Neighbour_5G"; strength: 2; secured: true; connected: false }
        ListElement { name: "Cafe_Guest"; strength: 1; secured: false; connected: false }
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

    function selectWifi(index) {
        for (let i = 0; i < wifiNetworks.count; ++i)
            wifiNetworks.setProperty(i, "connected", i === index);
        wifiEnabled = true;
        refresh();
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

    function refresh() {
        if (bluetoothEnabled) {
            // В плитке показываем только первое подключённое устройство:
            // полный список виден во внутренней панели.
            let first = "";
            for (let i = 0; i < bluetoothDevices.count; ++i) {
                const device = bluetoothDevices.get(i);
                if (device.connected) {
                    first = device.name;
                    break;
                }
            }
            bluetoothSummary = first !== "" ? first : "No devices";
        } else {
            bluetoothSummary = "Off";
        }

        if (wifiEnabled) {
            let name = "";
            for (let i = 0; i < wifiNetworks.count; ++i) {
                const network = wifiNetworks.get(i);
                if (network.connected) {
                    name = network.name;
                    break;
                }
            }
            wifiSummary = name !== "" ? name : "Not connected";
        } else {
            wifiSummary = "Off";
        }
    }

    Component.onCompleted: refresh()
}
