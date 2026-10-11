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

        function wifi(): string {
            UiState.open(UiState.defaultScreen(), "wifi");
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
                + " wifi=" + MockState.wifiNetworks.count
                + " devices=" + MockState.bluetoothDevices.count;
        }
    }
}
