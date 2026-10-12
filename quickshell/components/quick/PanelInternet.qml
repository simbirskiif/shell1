import QtQuick
import ".."
import "../../singletons"

// Панель «Интернет»: подключённый Ethernet, списки сетей Wi-Fi и диалог
// пароля. Данные и действия — в NetworkService; здесь только отображение.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    // Открытие панели, скан и периодическое обновление живут в NetworkService:
    // сервис сам следит за UiState.panel === "internet".

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Internet"
            wifiStatus: true
            checked: NetworkService.wifiEnabled
            refreshable: true
            refreshing: NetworkService.wifiScanning
            onBackRequested: root.backRequested()
            onToggled: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
            onRefreshRequested: NetworkService.scanWifi()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // --- список сетей ------------------------------------------------
        Column {
            width: parent.width
            spacing: 0

            // Заглушка, если nmcli/NM недоступны: показывать пустой список
            // хуже, чем объяснить причину.
            PanelDisabled {
                width: parent.width
                visible: !NetworkService.backendAvailable
                height: visible ? implicitHeight : 0
                icon: "\uf1eb"
                title: "No network backend"
                description: "NetworkManager is not available"
                actionText: ""
            }

            // Подключённый модем / проводное соединение — виден всегда.
            Item {
                id: ethernetRow
                width: parent.width
                height: NetworkService.ethernetConnected ? Theme.quickRowHeight : 0
                visible: height > 0
                clip: true

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkService.requestEthernet()
                }

                PanelIcon {
                    id: ethernetIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf1e6"
                    connected: NetworkService.internetViaEthernet
                }

                Text {
                    anchors.left: ethernetIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkService.ethernetName
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkService.ethernetSummary
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // Captive portal: сеть подключена, но интернет откроется только
            // после входа на странице.
            PortalBanner {
                width: parent.width
                visible: NetworkService.connectivity === "portal"
                height: visible ? implicitHeight : 0
                onSignInRequested: NetworkService.openPortal()
            }

            // Wi-Fi выключен — единый экран-заглушка.
            PanelDisabled {
                width: parent.width
                visible: NetworkService.backendAvailable && !NetworkService.wifiEnabled
                height: visible ? implicitHeight : 0
                wifiIcon: true
                icon: "\uf1eb"
                title: NetworkService.wifiHardBlocked ? "Wi-Fi is blocked" : "Wi-Fi is off"
                description: NetworkService.wifiHardBlocked
                             ? "Disabled by hardware switch"
                             : "Turn Wi-Fi on to see available networks"
                actionText: "Turn on"
                showAction: !NetworkService.wifiHardBlocked
                onActionRequested: NetworkService.toggleWifi()
            }

            // Wi-Fi включён: сначала сохранённые сети, затем доступные.
            Column {
                id: enabledContent
                width: parent.width
                visible: NetworkService.backendAvailable && NetworkService.wifiEnabled
                height: visible ? implicitHeight : 0
                spacing: 0

                PanelSection { text: "Saved" }

                PanelList {
                    width: parent.width
                    model: NetworkService.savedWifiNetworks

                    delegate: WifiRow {
                        onActivated: {
                            UiState.dialogScreen = UiState.openedScreen;
                            NetworkService.requestWifi(name);
                            if (NetworkService.pendingNetwork !== "")
                                UiState.close();
                        }
                        onContextRequested: (x, y) => {
                            UiState.openNetworkMenu(name, x, y);
                        }
                    }
                }

                PanelSection { text: "Available" }

                PanelList {
                    width: parent.width
                    model: NetworkService.wifiNetworks

                    delegate: WifiRow {
                        onActivated: {
                            UiState.dialogScreen = UiState.openedScreen;
                            NetworkService.requestWifi(name);
                            if (NetworkService.pendingNetwork !== "")
                                UiState.close();
                        }
                        onContextRequested: (x, y) => {
                            UiState.openNetworkMenu(name, x, y);
                        }
                    }
                }
            }
        }
    }
}
