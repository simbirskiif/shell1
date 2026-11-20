import QtQuick
import ".."
import "../../singletons"

// Выбор устройства вывода или ввода: список с отметкой текущего.
// kind: "output" — устройства вывода, "input" — ввода. Панель одна на оба
// случая, потому что отличается только источником списка и действием.
Item {
    id: root

    required property string kind

    signal backRequested()

    readonly property bool output: root.kind === "output"
    readonly property var devices: root.output ? AudioService.outputDevices : AudioService.inputDevices

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: root.output ? "Output device" : "Input device"
            checked: false
            switchable: false
            onBackRequested: root.backRequested()
        }

        // Разделитель шапки m3 — outline-variant.
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        PanelDisabled {
            width: parent.width
            readonly property bool shown: root.devices.length === 0
            visible: shown
            height: shown ? implicitHeight : 0
            icon: root.output ? "\uf028" : "\uf130"
            title: "No devices"
            description: root.output ? "No audio outputs found" : "No audio inputs found"
            actionText: ""
            showAction: false
        }

        PanelList {
            width: parent.width
            // Своё условие вместо visible: во время жеста скрытый предок
            // погасил бы и список, и высота панели схлопнулась бы.
            readonly property bool shown: root.devices.length > 0
            visible: shown
            height: shown ? implicitHeight : 0
            model: root.devices

            delegate: Item {
                id: deviceRow
                required property var modelData

                readonly property bool current: root.output
                    ? AudioService.isDefaultSink(modelData)
                    : AudioService.isDefaultSource(modelData)

                // m3 divider между строками: у последней строки списка нет.
                readonly property bool separatorVisible: ListView.view !== null
                    && (deviceRow.y + deviceRow.height) < ListView.view.contentHeight

                width: parent.width
                height: Theme.listItemHeight

                // Строка списка m3: прозрачный контейнер, hover — state layer.
                Rectangle {
                    anchors.fill: parent
                    color: rowHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                PanelIcon {
                    id: deviceIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.output ? "\uf028" : "\uf130"
                    connected: current
                }

                Text {
                    anchors.left: deviceIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: checkMark.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: AudioService.deviceLabel(modelData)
                    elide: Text.ElideRight
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                }

                Text {
                    id: checkMark
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    visible: current
                    text: "\uf00c"
                    color: Theme.primary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                // Разделитель m3: outline-variant, толщина 1, отступ 16.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    height: 1
                    color: Theme.outlineVariant
                    visible: deviceRow.separatorVisible
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.output)
                            AudioService.setDefaultSink(modelData);
                        else
                            AudioService.setDefaultSource(modelData);
                    }
                }
            }
        }
    }
}
