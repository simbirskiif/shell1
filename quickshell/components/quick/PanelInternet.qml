import QtQuick
import ".."
import "../../singletons"

// Панель «Интернет»: подключённый Ethernet, поиск и списки сетей.
// Когда Wi-Fi выключен — единый экран-заглушка вместо списков.
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
            refreshable: true
            refreshing: MockState.wifiScanning
            onBackRequested: root.backRequested()
            onToggled: {
                MockState.toggleWifi();
                MockState.scanWifi();
            }
            onRefreshRequested: MockState.scanWifi()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Подключённый модем / проводное соединение — виден всегда.
        Item {
            id: ethernetRow
            width: parent.width
            height: MockState.ethernetConnected ? Theme.quickRowHeight : 0
            visible: height > 0
            clip: true

            PanelIcon {
                id: ethernetIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf1e6"
                connected: MockState.internetViaEthernet
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
                text: MockState.internetViaEthernet ? MockState.ethernetSpeed : "Not active"
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        // Wi-Fi выключен — единый экран-заглушка.
        PanelDisabled {
            width: parent.width
            visible: !MockState.wifiEnabled
            height: visible ? implicitHeight : 0
            icon: "\uf1eb"
            title: "Wi-Fi is off"
            description: "Turn Wi-Fi on to see available networks"
            actionText: "Turn on"
            onActionRequested: {
                MockState.toggleWifi();
                MockState.scanWifi();
            }
        }

        // Wi-Fi включён: сначала сохранённые сети, затем доступные.
        Column {
            id: enabledContent
            width: parent.width
            visible: MockState.wifiEnabled
            height: visible ? implicitHeight : 0
            spacing: 0

            PanelSection { text: "Saved" }

            PanelList {
                width: parent.width
                model: MockState.savedWifiNetworks

                delegate: WifiRow {
                    onActivated: MockState.selectSavedWifi(name)
                }
            }

            PanelSection { text: "Available" }

            PanelList {
                width: parent.width
                model: MockState.wifiNetworks

                delegate: WifiRow {
                    onActivated: MockState.selectWifi(name)
                }
            }
        }
    }
}
