import QtQuick
import ".."
import "../../singletons"

// Панель «Интернет»: подключённый Ethernet, поиск и список доступных
// Wi-Fi сетей, ниже — сохранённые сети.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    // Открыли панель — запускаем поиск сетей.
    Connections {
        target: UiState

        function onPanelChanged() {
            if (UiState.panel === "internet")
                MockState.scanWifi();
        }
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Internet"
            checked: MockState.wifiEnabled
            onBackRequested: root.backRequested()
            onToggled: {
                MockState.toggleWifi();
                MockState.scanWifi();
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Подключённый модем / проводное соединение — над списком Wi-Fi.
        Item {
            id: ethernetRow
            width: parent.width
            height: MockState.ethernetConnected ? Theme.quickRowHeight : 0
            visible: height > 0
            clip: true
            Behavior on height {
                MotionNumber {
                    duration: Theme.motionMedium1
                    curve: Theme.curveEmphasized
                }
            }

            PanelIcon {
                id: ethernetIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf1e6"
                connected: true
            }

            Text {
                anchors.left: ethernetIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: MockState.ethernetName
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: MockState.ethernetSpeed
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        // Индикатор поиска сетей.
        Item {
            id: scanningRow
            width: parent.width
            height: MockState.wifiScanning ? 56 : 0
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
                    text: "Searching for networks…"
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }

        PanelSection { text: "Available" }

        PanelList {
            width: parent.width
            model: MockState.wifiNetworks

            delegate: WifiRow {
                onActivated: MockState.selectWifi(index)
            }
        }

        PanelSection { text: "Saved" }

        PanelList {
            width: parent.width
            model: MockState.savedWifiNetworks

            delegate: WifiRow {
                onActivated: MockState.selectSavedWifi(index)
            }
        }
    }
}
