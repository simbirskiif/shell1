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

    readonly property string soundSummary: {
        if (!soundEnabled)
            return "Muted";
        return Math.round(volume * 100) + "% · " + outputName;
    }

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

    function refresh() {
        if (bluetoothEnabled) {
            const connected = [];
            for (let i = 0; i < bluetoothDevices.count; ++i) {
                const device = bluetoothDevices.get(i);
                if (device.connected)
                    connected.push(device.name);
            }
            bluetoothSummary = connected.length > 0 ? connected.join(", ") : "No devices";
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
