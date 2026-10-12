// Точка входа конфигурации Quickshell.
// По одному бару на каждый экран; сам бар живёт в components/Bar.qml.
import Quickshell
import Quickshell.Io
import "components"
import "singletons"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Управление снаружи: qs ipc -p ~/shell/quickshell call bar <функция>.
    // Удобно повесить на бинд в Hyprland, например:
    //   bind = SUPER, A, exec, qs ipc -p ~/shell/quickshell call bar toggle
    IpcHandler {
        target: "bar"

        function toggle(): string {
            UiState.toggle(UiState.defaultScreen());
            return state();
        }

        function main(): string {
            UiState.open(UiState.defaultScreen(), "");
            return state();
        }

        function bluetooth(): string {
            UiState.open(UiState.defaultScreen(), "bluetooth");
            return state();
        }

        function internet(): string {
            UiState.open(UiState.defaultScreen(), "internet");
            return state();
        }

        // Прежнее имя панели Wi-Fi, теперь это «Интернет».
        function wifi(): string {
            return internet();
        }

        // Яркость (тестовая заглушка): погасить/вернуть.
        function toggleBrightness(): string {
            MockState.toggleBrightness();
            return state();
        }

        // Состояние питания (тестовое): зарядка вкл/выкл.
        function toggleCharging(): string {
            MockState.toggleCharging();
            return state();
        }

        // Переключатели радио — удобно для проверки состояний.
        function toggleWifi(): string {
            NetworkService.toggleWifi();
            NetworkService.scanWifi();
            return state();
        }

        // Явные состояния radio (проверка без гонки с оптимистичным UI).
        function wifiOn(): string {
            NetworkService.setWifiEnabled(true);
            NetworkService.scanWifi();
            return state();
        }

        function wifiOff(): string {
            NetworkService.setWifiEnabled(false);
            return state();
        }

        function toggleBluetooth(): string {
            MockState.toggleBluetooth();
            return state();
        }

        // Обновить список сетей (скан).
        function scanWifi(): string {
            NetworkService.scanWifi();
            return state();
        }

        // Подключение/отключение сети по имени из моделей сервиса.
        function wifiConnect(name: string): string {
            NetworkService.requestWifi(name);
            return state();
        }

        // То же по индексу в списке доступных сетей (для скриптов).
        function wifiConnectIndex(index: int): string {
            const model = NetworkService.wifiNetworks.count > 0
                        ? NetworkService.wifiNetworks : NetworkService.savedWifiNetworks;
            const network = model.get(index);
            if (network)
                NetworkService.requestWifi(network.name);
            return state();
        }

        function password(value: string): string {
            NetworkService.pendingPassword = value;
            return state();
        }

        function submitPassword(value: string): string {
            NetworkService.submitPassword(value !== "" ? value : NetworkService.pendingPassword);
            return state();
        }

        function cancelPassword(): string {
            NetworkService.cancelPending();
            return state();
        }

        function openPortal(): string {
            NetworkService.openPortal();
            return state();
        }

        // Список сетей и профилей — для проверки без мыши и скриншотов.
        function networks(): string {
            const parts = [];
            for (let i = 0; i < NetworkService.savedWifiNetworks.count; ++i) {
                const n = NetworkService.savedWifiNetworks.get(i);
                parts.push("saved[" + i + "]=" + n.name + "/" + n.security
                           + (n.connected ? "/on" : "") + (n.connecting ? "/..." : ""));
            }
            for (let i = 0; i < NetworkService.wifiNetworks.count; ++i) {
                const n = NetworkService.wifiNetworks.get(i);
                parts.push("avail[" + i + "]=" + n.name + "/" + n.security + "/sig" + n.strength
                           + (n.connected ? "/on" : "") + (n.connecting ? "/..." : ""));
            }
            return parts.join(" ");
        }

        // Подробности для отладки: устройство, маршрут, скорость.
        function net(): string {
            return "dev=" + (NetworkService.wifiDev || "-")
                + " state=" + (NetworkService.wifiDevState || "-")
                + " hw=" + NetworkService.wifiHardBlocked
                + " wiredDev=" + (NetworkService.ethernetName || "-")
                + " wiredState=" + (NetworkService.ethernetState || "-")
                + " speed=" + (NetworkService.ethernetSpeed || "-")
                + " route=" + (NetworkService.defaultRouteDev || "-")
                + " connectivity=" + NetworkService.connectivity;
        }

        function ethernet(): string {
            NetworkService.requestEthernet();
            return state();
        }

        // Жест «назад»: сдвинуть/завершить (для проверки без тачпада).
        function swipe(delta: real): string {
            UiState.swipeBy(delta, Theme.quickWidth);
            return state();
        }

        function endSwipe(): string {
            UiState.endSwipe();
            return state();
        }

        function discoverable(): string {
            MockState.toggleDiscoverable();
            return state();
        }

        // Заново запустить поиск сетей и устройств.
        function rescan(): string {
            NetworkService.scanWifi();
            MockState.scanBluetooth();
            return state();
        }

        function brightness(): string {
            UiState.open(UiState.defaultScreen(), "brightness");
            return state();
        }

        // Порядок элементов бара: сдвинуть первый в конец (для проверки).
        function rotateBarItems(): string {
            if (MockState.barItems.count > 1)
                MockState.barItems.move(0, MockState.barItems.count - 1, 1);
            return state();
        }

        // Настройка бара: показывать ли процент батареи.
        function toggleBarBattery(): string {
            MockState.showBatteryPercent = !MockState.showBatteryPercent;
            return state();
        }

        // Режим редактирования плиток: вход, сохранить, отменить.
        function edit(): string {
            UiState.open(UiState.defaultScreen(), "");
            UiState.beginEdit();
            return state();
        }

        function saveEdit(): string {
            UiState.saveEdit();
            return state();
        }

        function cancelEdit(): string {
            UiState.cancelEdit();
            return state();
        }

        // Операции редактора (проверка без мыши): скрыть/вернуть/переставить.
        function hideTile(index: int): string {
            UiState.hideTile(UiState.draftVisible[index]);
            return state();
        }

        function showTile(index: int): string {
            UiState.showTile(UiState.draftAvailable[index]);
            return state();
        }

        function moveTile(from: int, to: int): string {
            UiState.moveTile(from, to);
            return state();
        }

        function settings(): string {
            UiState.open(UiState.defaultScreen(), "settings");
            return state();
        }

        function battery(): string {
            UiState.open(UiState.defaultScreen(), "battery");
            return state();
        }

        function sound(): string {
            UiState.open(UiState.defaultScreen(), "sound");
            return state();
        }

        function close(): string {
            UiState.close();
            return state();
        }

        // Демо-строки: посмотреть анимации появления/удаления в списках.
        function addWifi(): string {
            NetworkService.addDemoNetwork();
            return state();
        }

        function removeWifi(): string {
            NetworkService.removeDemoNetwork();
            return state();
        }

        function addDevice(): string {
            MockState.addBluetoothDevice();
            return state();
        }

        function removeDevice(): string {
            MockState.removeBluetoothDevice();
            return state();
        }

        // Принудительно перечитать палитру pywal.
        function palette(): string {
            Wal.reload();
            return state();
        }

        function state(): string {
            const order = [];
            const tiles = (UiState.editing ? UiState.draftVisible : MockState.visibleTiles).join(",");
            for (let i = 0; i < MockState.barItems.count; ++i)
                order.push(MockState.barItems.get(i).itemKey);
            return "opened=" + (UiState.openedScreen === "" ? "no" : UiState.openedScreen)
                + " panel=" + (UiState.panel === "" ? "main" : UiState.panel)
                + " palette=" + (Wal.walLoaded ? "wal" : "fallback")
                + " bg=" + Wal.background + " accent=" + Wal.accent
                + " brightness=" + Math.round(MockState.brightness * 100) + "%"
                + " h=" + Math.round(UiState.popupHeight)
                + " tiles=" + tiles + (UiState.editing ? " [edit]" : "")
                + " order=" + order.join(",")
                + " barPercent=" + (MockState.showBatteryPercent ? "on" : "off")
                + " battery=" + MockState.batteryLevel + "%" + (MockState.batteryCharging ? "+" : "")
                + " mode=" + MockState.powerMode
                + " eth=" + (NetworkService.ethernetConnected
                             ? (NetworkService.internetViaEthernet ? "active" : "idle") : "off")
                + " ethName=" + (NetworkService.ethernetName || "-")
                + " ethSpeed=" + (NetworkService.ethernetSpeed || "-")
                + " scanning=" + (NetworkService.wifiScanning || MockState.bluetoothScanning)
                + " swipe=" + UiState.swipe.toFixed(2)
                + " pending=" + (NetworkService.pendingNetwork === "" ? "no" : NetworkService.pendingNetwork)
                + " connecting=" + (NetworkService.connectingName || MockState.connectingDevice || "no")
                + " err=" + (NetworkService.connectError || "-")
                + " connectivity=" + NetworkService.connectivity
                + " backend=" + (NetworkService.backendAvailable ? "ok" : "down")
                + " radio=" + (NetworkService.wifiEnabled ? "on" : "off")
                + " hwblock=" + (NetworkService.wifiHardBlocked ? "yes" : "no")
                + " discoverable=" + (MockState.bluetoothDiscoverable ? "on" : "off")
                + " wifi=" + NetworkService.wifiNetworks.count
                + " saved=" + NetworkService.savedWifiNetworks.count
                + " ssid=" + (NetworkService.connectedSsid || "-")
                + " devices=" + MockState.bluetoothDevices.count;
        }
    }
}

