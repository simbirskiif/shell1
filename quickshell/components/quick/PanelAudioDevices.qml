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

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
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
                required property var modelData

                readonly property bool current: root.output
                    ? AudioService.isDefaultSink(modelData)
                    : AudioService.isDefaultSource(modelData)

                width: parent.width
                height: Theme.quickRowHeight

                Rectangle {
                    anchors.fill: parent
                    color: rowHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                PanelIcon {
                    id: deviceIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.output ? "\uf028" : "\uf130"
                    connected: current
                }

                Text {
                    anchors.left: deviceIcon.right
                    anchors.leftMargin: 12
                    anchors.right: checkMark.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: AudioService.deviceLabel(modelData)
                    elide: Text.ElideRight
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    id: checkMark
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: current
                    text: "\uf00c"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 13
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
