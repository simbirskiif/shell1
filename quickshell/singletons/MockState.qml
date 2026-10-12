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

    // Настройки оболочки.
    property bool showBatteryPercent: true

    // Набор плиток основной панели: видимые (в порядке) и доступные.
    // Меняется только кнопкой «Сохранить» в режиме редактирования.
    property var visibleTiles: ["bluetooth", "internet", "sound", "brightness"]
    property var availableTiles: []

    // Порядок элементов в баре: порядок в модели = слева-направо.
    readonly property ListModel barItems: ListModel {
        ListElement { itemKey: "battery"; title: "Battery" }
        ListElement { itemKey: "status"; title: "Quick settings" }
    }

    function moveBarItem(index, delta) {
        const target = index + delta;
        if (target < 0 || target >= barItems.count)
            return;
        barItems.move(index, target, 1);
    }

    // Яркость экрана (пока заглушка). lastBrightness — чтобы вернуть
    // прежнее значение после «выключения» кружком.
    property real brightness: 0.7
    property real lastBrightness: 0.7

    function toggleBrightness() {
        if (brightness > 0) {
            lastBrightness = brightness;
            brightness = 0;
        } else {
            brightness = lastBrightness > 0 ? lastBrightness : 0.7;
        }
    }

    // Батарея и питание.
    property int batteryLevel: 82
    property bool batteryCharging: false
    property int batteryMinutes: 252
    property string powerMode: "Balanced"

    readonly property var powerModes: ["Saver", "Balanced", "Performance"]

    readonly property string batteryState: batteryCharging ? "Charging" : "Discharging"

    readonly property string batteryTime: {
        const hours = Math.floor(batteryMinutes / 60);
        const minutes = batteryMinutes % 60;
        const suffix = batteryCharging ? "until full" : "remaining";
        if (hours > 0)
            return hours + " h " + minutes + " min " + suffix;
        return minutes + " min " + suffix;
    }

    // Демо: переключить «зарядку», чтобы посмотреть второе состояние.
    function toggleCharging() {
        batteryCharging = !batteryCharging;
        batteryMinutes = batteryCharging ? 74 : 252;
    }

    // Ethernet: если подключён, в панели «Интернет» над списком Wi-Fi
    // показывается подключённый модем / проводное соединение.
    property bool ethernetConnected: true
    // Модем может быть подключён, но не быть активным подключением.
    property bool ethernetActive: true
    property string ethernetName: "Ethernet"
    property string ethernetSpeed: "1 Gbit/s"

    // Активный интернет идёт через ethernet только если он подключён И активен.
    readonly property bool internetViaEthernet: ethernetConnected && ethernetActive

    // Поиск сетей и устройств: пока идёт — в панели виден индикатор.
    property bool wifiScanning: false
    property bool bluetoothScanning: false

    // Короткие подписи для плиток; пересчитываются в refresh().
    property string bluetoothSummary: ""
    property string wifiSummary: ""

    readonly property string internetSummary: {
        if (internetViaEthernet)
            return ethernetName;
        // Модема нет или он не активен — показываем состояние Wi-Fi.
        if (!wifiEnabled)
            return "Off";
        return wifiSummary !== "" ? wifiSummary : "Not connected";
    }

    // Иконки — глифы JetBrainsMono Nerd Font.
    // security: "open" | "psk" (нужен пароль) | "enterprise" (нужны
    // сертификаты и прочие доп. действия — такие сети помечаем «!»).
    readonly property ListModel wifiNetworks: ListModel {
        ListElement { name: "Home_5G"; strength: 4; security: "psk"; saved: true; connected: true; connecting: false }
        ListElement { name: "Home_2.4G"; strength: 3; security: "psk"; saved: true; connected: false; connecting: false }
        ListElement { name: "Neighbour_5G"; strength: 2; security: "psk"; saved: false; connected: false; connecting: false }
        ListElement { name: "Cafe_Guest"; strength: 1; security: "open"; saved: false; connected: false; connecting: false }
        ListElement { name: "Corp_8021x"; strength: 3; security: "enterprise"; saved: false; connected: false; connecting: false }
    }

    // Сохранённые сети: заготовка под «известные» сети вне зоны видимости.
    // strength 0 = уровень неизвестен.
    readonly property ListModel savedWifiNetworks: ListModel {
        ListElement { name: "Office_WiFi"; strength: 0; security: "psk"; saved: true; connected: false; connecting: false }
        ListElement { name: "Phone_Hotspot"; strength: 0; security: "psk"; saved: true; connected: false; connecting: false }
    }

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

    // Ищем по имени: index в делегатах-компонентах не приходит из модели.

    // --- подключение Wi-Fi -------------------------------------------------
    // Сеть, для которой спрашиваем пароль, и набранный пароль.
    property string pendingNetwork: ""
    property string pendingPassword: ""
    property string connectingWifi: ""

    function wifiListOf(name) {
        for (let i = 0; i < savedWifiNetworks.count; ++i) {
            if (savedWifiNetworks.get(i).name === name)
                return savedWifiNetworks;
        }
        return wifiNetworks;
    }

    function wifiIndexOf(name) {
        const list = root.wifiListOf(name);
        for (let i = 0; i < list.count; ++i) {
            if (list.get(i).name === name)
                return i;
        }
        return -1;
    }

    // Решение по нажатию на сеть: пароль -> форма, доп. действия -> ничего,
    // иначе сразу показываем индикатор подключения.
    function requestWifi(name) {
        const index = root.wifiIndexOf(name);
        if (index < 0)
            return;
        const network = root.wifiListOf(name).get(index);
        if (network.security === "enterprise")
            return;
        if (network.security === "psk" && !network.saved) {
            root.pendingNetwork = name;
            root.pendingPassword = "";
            return;
        }
        root.startWifiConnect(name);
    }

    function submitPassword() {
        if (root.pendingNetwork === "")
            return;
        root.startWifiConnect(root.pendingNetwork);
    }

    function cancelPassword() {
        root.pendingNetwork = "";
        root.pendingPassword = "";
    }

    function startWifiConnect(name) {
        root.pendingNetwork = "";
        for (let i = 0; i < wifiNetworks.count; ++i)
            wifiNetworks.setProperty(i, "connecting", wifiNetworks.get(i).name === name);
        for (let i = 0; i < savedWifiNetworks.count; ++i)
            savedWifiNetworks.setProperty(i, "connecting", savedWifiNetworks.get(i).name === name);
        root.connectingWifi = name;
        wifiConnectTimer.restart();
    }

    Timer {
        id: wifiConnectTimer
        interval: 1600
        onTriggered: {
            for (let i = 0; i < wifiNetworks.count; ++i)
                wifiNetworks.setProperty(i, "connected", wifiNetworks.get(i).name === root.connectingWifi);
            for (let i = 0; i < savedWifiNetworks.count; ++i)
                savedWifiNetworks.setProperty(i, "connected", savedWifiNetworks.get(i).name === root.connectingWifi);
            for (let i = 0; i < wifiNetworks.count; ++i)
                wifiNetworks.setProperty(i, "connecting", false);
            for (let i = 0; i < savedWifiNetworks.count; ++i)
                savedWifiNetworks.setProperty(i, "connecting", false);
            root.connectingWifi = "";
            root.wifiEnabled = true;
            refresh();
        }
    }

    // --- Bluetooth ---------------------------------------------------------
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
