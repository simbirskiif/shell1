import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Выбор устройства вывода или ввода: список с отметкой текущего.
// kind: "output" — устройства вывода, "input" — ввода. Панель одна на оба
// случая, потому что отличается только источником списка и действием.
//
// Expressive: текущее устройство — крупная пилюля primary-container с орбом
// «sunny»; остальные строки прозрачные с hover-слоем. Разделителей нет.
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
            rowHeight: 62
            model: root.devices

            delegate: Item {
                id: deviceRow
                required property var modelData

                readonly property bool current: root.output
                    ? AudioService.isDefaultSink(modelData)
                    : AudioService.isDefaultSource(modelData)

                readonly property bool hovered: rowHover.containsMouse
                readonly property bool pressed: rowHover.pressed

                readonly property color rowColor: current ? Theme.primaryContainer
                                                  : hovered ? Theme.surfaceContainerHigh
                                                  : "transparent"
                readonly property color ink: current ? Theme.scheme.onPrimaryContainer
                                                     : Theme.scheme.onSurface

                width: parent.width
                height: 62

                scale: pressed ? 0.98 : 1
                Behavior on scale { SpringSpatialFast {} }

                MorphShape {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    shape: deviceRow.current ? "pill" : "squircle"
                    color: deviceRow.rowColor
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                // Орб устройства: выбранное — «солнышко» tertiary-контейнера
                // внутри primary-пилюли, остальные — круг на тональной.
                MorphShape {
                    id: deviceOrb
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    shape: deviceRow.current ? "sunny" : "circle"
                    color: deviceRow.current ? Theme.tertiaryContainer : Theme.surfaceContainerHighest
                    modulation: 1

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.output ? "\uf028" : "\uf130"
                        color: deviceRow.current ? Theme.scheme.onTertiaryContainer
                                                 : Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 20
                    }
                }

                Text {
                    anchors.left: deviceOrb.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: checkMark.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: AudioService.deviceLabel(modelData)
                    elide: Text.ElideRight
                    color: deviceRow.ink
                    font: deviceRow.current ? Theme.typeEmphasizedLabelLarge
                                            : Theme.typeBodyLarge
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: checkMark
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    visible: deviceRow.current
                    text: "\uf00c"
                    color: Theme.scheme.onPrimaryContainer
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
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
