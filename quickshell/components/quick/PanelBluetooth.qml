import QtQuick
import ".."
import "../../singletons"

// Панель Bluetooth: поиск устройств, список сохранённых (спаренных)
// устройств и список найденных. Подключённые обведены кольцом.
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
            onBackRequested: root.backRequested()
            onToggled: {
                MockState.toggleBluetooth();
                MockState.scanBluetooth();
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Индикатор поиска устройств.
        Item {
            id: scanningRow
            width: parent.width
            height: MockState.bluetoothScanning ? 56 : 0
            visible: height > 0
            clip: true
            Behavior on height {
                MotionNumber {
                    duration: Theme.motionMedium1
                    curve: Theme.curveEmphasized
                }
            }

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
                onActivated: MockState.toggleSavedDevice(index)
            }
        }

        PanelSection { text: "Available" }

        PanelList {
            width: parent.width
            model: MockState.bluetoothDevices

            delegate: BluetoothRow {
                onActivated: MockState.toggleDevice(index)
            }
        }
    }
}
