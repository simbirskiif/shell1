import QtQuick
import QtQuick.Layouts
import "../../singletons"

// Содержимое попапа. Один список описаний панелей создаёт и плитку
// в сетке 2 столбца, и дочерний вид: добавить панель = добавить запись.
// Открытая панель хранится в UiState, поэтому связь «плитка ↔ дочерний
// вид» — это просто ключ дескриптора, без локальных копий состояния.
Item {
    id: root

    readonly property string panel: UiState.panel

    readonly property var panels: [bluetoothEntry, internetEntry, soundEntry, brightnessEntry, batteryEntry]

    // В сетке плиток показываем не все панели: батарея живёт в шапке.
    readonly property var gridPanels: root.panels.filter(entry => entry.inGrid)

    readonly property Item activeDetail: {
        for (let i = 0; i < detailViews.count; ++i) {
            const view = detailViews.itemAt(i);
            if (view && view.active)
                return view;
        }
        return null;
    }

    implicitWidth: Theme.quickWidth
    implicitHeight: {
        if (mainView.active)
            return mainView.implicitHeight;
        return root.activeDetail ? root.activeDetail.implicitHeight : mainView.implicitHeight;
    }

    PanelView {
        id: mainView
        anchors.fill: parent
        active: root.panel === ""

        Column {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Theme.quickTileSpacing

            // Шапка основной панели: справа — батарея.
            Item {
                width: parent.width
                height: 36

                BatteryButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    level: MockState.batteryLevel
                    charging: MockState.batteryCharging
                    onClicked: batteryEntry.open()
                }
            }

            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: Theme.quickTileSpacing
                rowSpacing: Theme.quickTileSpacing

                Repeater {
                    model: root.gridPanels

                    delegate: QuickTile {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.quickTileHeight
                        icon: modelData.icon
                        title: modelData.title
                        subtitle: modelData.subtitle
                        active: modelData.active
                        onToggled: modelData.toggle()
                        onExpandRequested: modelData.open()
                    }
                }
            }
        }
    }

    Repeater {
        id: detailViews
        model: root.panels

        delegate: PanelView {
            required property var modelData

            anchors.fill: parent
            active: root.panel === modelData.key

            Loader {
                id: viewLoader
                anchors.fill: parent
                sourceComponent: modelData.view
            }

            // Кнопка «назад» внутри панели возвращает к сетке плиток.
            Connections {
                target: viewLoader.item

                function onBackRequested() {
                    UiState.closeDetail();
                }
            }
        }
    }

    // Единое описание панели: иконка, подписи, состояние, действия и
    // дочерний вид. Одна запись создаёт и плитку, и окно управления;
    // open() связывает плитку с её дочерним видом через ключ.
    QtObject {
        id: bluetoothEntry

        readonly property bool inGrid: true
        readonly property string key: "bluetooth"
        readonly property string title: "Bluetooth"
        readonly property string icon: "\uf293"
        readonly property bool active: MockState.bluetoothEnabled
        readonly property string subtitle: MockState.bluetoothSummary
        readonly property Component view: Component { PanelBluetooth {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleBluetooth();
        }
    }

    QtObject {
        id: internetEntry

        readonly property bool inGrid: true
        readonly property string key: "internet"
        readonly property string title: "Internet"
        readonly property string icon: "\uf0ac"
        readonly property bool active: MockState.wifiEnabled || MockState.ethernetConnected
        readonly property string subtitle: MockState.internetSummary
        readonly property Component view: Component { PanelInternet {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleWifi();
        }
    }

    QtObject {
        id: soundEntry

        readonly property bool inGrid: true
        readonly property string key: "sound"
        readonly property string title: "Sound"
        readonly property string icon: MockState.soundEnabled ? "\uf028" : "\uf026"
        readonly property bool active: MockState.soundEnabled
        readonly property string subtitle: MockState.soundSummary
        readonly property Component view: Component { PanelSound {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleSound();
        }
    }

    // Яркость: плитка как у звука. Кружок слева ничего не делает,
    // нажатие на остальную часть открывает панель яркости.
    QtObject {
        id: brightnessEntry

        readonly property bool inGrid: true
        readonly property string key: "brightness"
        readonly property string title: "Brightness"
        readonly property string icon: "\uf185"
        readonly property bool active: MockState.brightness > 0
        readonly property string subtitle: Math.round(MockState.brightness * 100) + "%"
        readonly property Component view: Component { PanelBrightness {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            // У яркости кружок ничего не переключает.
        }
    }

    // Батарея: не плитка, а кнопка в шапке основной панели,
    // но дочерний вид создаётся тем же механизмом.
    QtObject {
        id: batteryEntry

        readonly property bool inGrid: false
        readonly property string key: "battery"
        readonly property string title: "Battery"
        readonly property string icon: "\uf240"
        readonly property bool active: MockState.batteryCharging
        readonly property string subtitle: MockState.batteryLevel + "%"
        readonly property Component view: Component { PanelBattery {} }

        function open() {
            UiState.openDetail(key);
        }

        function toggle() {
            MockState.toggleCharging();
        }
    }
}
