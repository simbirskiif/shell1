import QtQuick
import QtQuick.Layouts
import "../../singletons"

// Содержимое попапа. Один список описаний панелей создаёт и плитку
// в сетке 2 столбца, и дочерний вид: добавить панель = добавить запись.
Item {
    id: root

    property string panel: ""

    readonly property var panels: [bluetoothEntry, wifiEntry, soundEntry]

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

        GridLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            columns: 2
            columnSpacing: Theme.quickTileSpacing
            rowSpacing: Theme.quickTileSpacing

            Repeater {
                model: root.panels

                delegate: QuickTile {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.quickTileHeight
                    icon: modelData.icon
                    title: modelData.title
                    subtitle: modelData.subtitle
                    active: modelData.active
                    onToggled: modelData.toggle()
                    onExpandRequested: root.panel = modelData.key
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
                anchors.fill: parent
                sourceComponent: modelData.view
            }
        }
    }

    // Единое описание панели: иконка, подписи, состояние, действие и
    // дочерний вид. Одна запись создаёт и плитку, и окно управления.
    QtObject {
        id: bluetoothEntry

        readonly property string key: "bluetooth"
        readonly property string title: "Bluetooth"
        readonly property string icon: "\uf293"
        readonly property bool active: MockState.bluetoothEnabled
        readonly property string subtitle: MockState.bluetoothSummary
        readonly property Component view: Component { PanelBluetooth {} }

        function toggle() {
            MockState.toggleBluetooth();
        }
    }

    QtObject {
        id: wifiEntry

        readonly property string key: "wifi"
        readonly property string title: "Wi-Fi"
        readonly property string icon: "\uf1eb"
        readonly property bool active: MockState.wifiEnabled
        readonly property string subtitle: MockState.wifiSummary
        readonly property Component view: Component { PanelWifi {} }

        function toggle() {
            MockState.toggleWifi();
        }
    }

    QtObject {
        id: soundEntry

        readonly property string key: "sound"
        readonly property string title: "Sound"
        readonly property string icon: MockState.soundEnabled ? "\uf028" : "\uf026"
        readonly property bool active: MockState.soundEnabled
        readonly property string subtitle: MockState.soundSummary
        readonly property Component view: Component { PanelSound {} }

        function toggle() {
            MockState.toggleSound();
        }
    }
}
