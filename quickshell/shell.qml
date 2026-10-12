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

        function toggleEthernet(): string {
            MockState.ethernetConnected = !MockState.ethernetConnected;
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
            return "opened=" + (UiState.openedScreen === "" ? "no" : UiState.openedScreen)
                + " panel=" + (UiState.panel === "" ? "main" : UiState.panel)
                + " palette=" + (Wal.walLoaded ? "wal" : "fallback")
                + " bg=" + Wal.background + " accent=" + Wal.accent
                + " brightness=" + Math.round(MockState.brightness * 100) + "%"
                + " battery=" + MockState.batteryLevel + "%" + (MockState.batteryCharging ? "+" : "")
                + " mode=" + MockState.powerMode
                + " ethernet=" + (MockState.ethernetConnected ? "on" : "off")
                + " scanning=" + (MockState.wifiScanning || MockState.bluetoothScanning)
                + " wifi=" + MockState.wifiNetworks.count
                + " devices=" + MockState.bluetoothDevices.count;
        }
    }
}












