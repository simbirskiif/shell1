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
            MockState.toggleWifi();
            return state();
        }

        function toggleBluetooth(): string {
            MockState.toggleBluetooth();
            return state();
        }

        // Цикл: активен -> подключён, но не активен -> отключён -> активен.
        function toggleEthernet(): string {
            if (!MockState.ethernetConnected) {
                MockState.ethernetConnected = true;
                MockState.ethernetActive = true;
            } else if (MockState.ethernetActive) {
                MockState.ethernetActive = false;
            } else {
                MockState.ethernetConnected = false;
            }
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

        // Сценарии подключения (для проверки без мыши).
        function wifiConnect(index: int): string {
            const network = MockState.wifiNetworks.get(index);
            if (network)
                MockState.requestWifi(network.name);
            return state();
        }

        function password(value: string): string {
            MockState.pendingPassword = value;
            return state();
        }

        function submitPassword(): string {
            MockState.submitPassword();
            return state();
        }

        function cancelPassword(): string {
            MockState.cancelPassword();
            return state();
        }

        function discoverable(): string {
            MockState.toggleDiscoverable();
            return state();
        }

        // Заново запустить поиск сетей и устройств.
        function rescan(): string {
            MockState.scanWifi();
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
            MockState.addWifiNetwork();
            return state();
        }

        function removeWifi(): string {
            MockState.removeWifiNetwork();
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
                + " ethernet=" + (MockState.ethernetConnected ? (MockState.ethernetActive ? "active" : "idle") : "off")
                + " scanning=" + (MockState.wifiScanning || MockState.bluetoothScanning)
                + " swipe=" + UiState.swipe.toFixed(2)
                + " pending=" + (MockState.pendingNetwork === "" ? "no" : MockState.pendingNetwork)
                + " connecting=" + (MockState.connectingWifi || MockState.connectingDevice || "no")
                + " discoverable=" + (MockState.bluetoothDiscoverable ? "on" : "off")
                + " wifi=" + MockState.wifiNetworks.count
                + " devices=" + MockState.bluetoothDevices.count;
        }
    }
}
