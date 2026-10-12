import QtQuick
import ".."
import "../../singletons"

// Панель Bluetooth: поиск, сохранённые (спаренные) устройства и найденные.
// Когда Bluetooth выключен — единый экран-заглушка.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    // Открыли панель — запускаем поиск устройств.
    Connections {
        target: UiState

        function onPanelChanged() {
            if (UiState.panel === "bluetooth")
                MockState.scanBluetooth();
        }
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Bluetooth"
            checked: MockState.bluetoothEnabled
            refreshable: true
            refreshing: MockState.bluetoothScanning
            onBackRequested: root.backRequested()
            onToggled: {
                MockState.toggleBluetooth();
                MockState.scanBluetooth();
            }
            onRefreshRequested: MockState.scanBluetooth()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Bluetooth выключен — единый экран-заглушка.
        PanelDisabled {
            width: parent.width
            visible: !MockState.bluetoothEnabled
            height: visible ? implicitHeight : 0
            icon: "\uf293"
            title: "Bluetooth is off"
            description: "Turn Bluetooth on to find nearby devices"
            actionText: "Turn on"
            onActionRequested: {
                MockState.toggleBluetooth();
                MockState.scanBluetooth();
            }
        }

        Column {
            id: enabledContent
            width: parent.width
            visible: MockState.bluetoothEnabled
            height: visible ? implicitHeight : 0
            spacing: 0

            Item {
                id: scanningRow
                width: parent.width
                height: MockState.bluetoothScanning ? 56 : 0
                visible: height > 0
                clip: true

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    LoadingIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Searching for devices…"
                        color: Theme.quickTextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            PanelSection { text: "My devices" }

            PanelList {
                width: parent.width
                model: MockState.savedBluetoothDevices

                delegate: BluetoothRow {
                    onActivated: MockState.toggleSavedDevice(name)
                }
            }

            PanelSection { text: "Available" }

            PanelList {
                width: parent.width
                model: MockState.bluetoothDevices

                delegate: BluetoothRow {
                    onActivated: MockState.toggleDevice(name)
                }
            }
        }
    }
}
