import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель «Интернет»: подключённый Ethernet, списки сетей Wi-Fi и диалог
// пароля. Данные и действия — в NetworkService; здесь только отображение.
//
// Expressive: списки — крупные строки-пилюли с воздухом вместо разделителей,
// заголовки секций — typeEmphasizedTitleMedium, подключённое соединение и
// выбранная сеть выделены контейнерами.
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

        // --- список сетей ------------------------------------------------
        Column {
            width: parent.width
            spacing: 0

            // Заглушка, если nmcli/NM недоступны: показывать пустой список
            // хуже, чем объяснить причину.
            PanelDisabled {
                width: parent.width
                // Высоту считаем от своего условия, а не от visible: visible
                // гаснет и вместе со скрытым предком (вид уезжает в жесте),
                // и тогда высота панели схлопывалась прямо посреди движения.
                readonly property bool shown: !NetworkService.backendAvailable
                visible: shown
                height: shown ? implicitHeight : 0
                icon: "\uf1eb"
                title: "No network backend"
                description: "NetworkManager is not available"
                actionText: ""
            }

            // Подключённый модем / проводное соединение — виден всегда.
            // Expressive: это выбранное подключение, поэтому строка — крупная
            // пилюля primary-container с орбом «печенье» tertiary-контейнера.
            Item {
                id: ethernetRow
                width: parent.width
                height: NetworkService.ethernetConnected ? 64 : 0
                visible: height > 0
                clip: true

                readonly property bool hovered: ethernetHover.containsMouse
                readonly property bool pressed: ethernetHover.pressed

                scale: pressed ? 0.98 : 1
                Behavior on scale { SpringSpatialFast {} }

                MorphShape {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    shape: ethernetRow.hovered ? "squircle" : "pill"
                    color: Theme.primaryContainer
                    modulation: 0.35
                }

                MouseArea {
                    id: ethernetHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkService.requestEthernet()
                }

                MorphShape {
                    id: ethernetOrb
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    shape: "cookie"
                    color: Theme.tertiaryContainer
                    modulation: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\uf1e6"
                        color: Theme.scheme.onTertiaryContainer
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 20
                    }
                }

                Text {
                    anchors.left: ethernetOrb.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: ethernetSummary.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: NetworkService.ethernetName
                    color: Theme.scheme.onPrimaryContainer
                    font: Theme.typeEmphasizedLabelLarge
                }

                Text {
                    id: ethernetSummary
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkService.ethernetSummary
                    color: Theme.withAlpha(Theme.scheme.onPrimaryContainer, 0.75)
                    font: Theme.typeLabelLarge
                }
            }

            // Captive portal: сеть подключена, но интернет откроется только
            // после входа на странице.
            PortalBanner {
                width: parent.width
                readonly property bool shown: NetworkService.connectivity === "portal"
                visible: shown
                height: shown ? implicitHeight : 0
                onSignInRequested: NetworkService.openPortal()
            }

            // Wi-Fi выключен — единый экран-заглушка.
            PanelDisabled {
                width: parent.width
                readonly property bool shown: NetworkService.backendAvailable && !NetworkService.wifiEnabled
                visible: shown
                height: shown ? implicitHeight : 0
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
                readonly property bool shown: NetworkService.backendAvailable && NetworkService.wifiEnabled
                visible: shown
                height: shown ? implicitHeight : 0
                spacing: 0

                // Заголовок секции Expressive: крупнее и жирнее обычной подписи.
                Item {
                    width: parent.width
                    height: 40

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.xs
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.space.xs
                        text: "Saved"
                        color: Theme.primary
                        font: Theme.typeEmphasizedTitleMedium
                    }
                }

                PanelList {
                    width: parent.width
                    rowHeight: 62
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

                Item {
                    width: parent.width
                    height: 40

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.xs
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.space.xs
                        text: "Available"
                        color: Theme.primary
                        font: Theme.typeEmphasizedTitleMedium
                    }
                }

                PanelList {
                    width: parent.width
                    rowHeight: 62
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
