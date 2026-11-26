import QtQuick
import "../../singletons"

// Компактный выбор одной входящей иконки составной кнопки (Wi-Fi,
// Bluetooth, звук). options: { value, glyph, label }; value "auto" —
// живой значок, "" — скрыть, иначе глиф.
Item {
    id: root

    property string title: ""
    property var options: []
    property string value: ""

    signal picked(string value)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: parent.width
        spacing: Theme.space.sm

        Text {
            width: parent.width
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeBodyMedium
        }

        Flow {
            width: parent.width
            spacing: Theme.space.sm

            Repeater {
                model: root.options

                delegate: Item {
                    id: option

                    required property var modelData

                    readonly property bool selected: root.value === modelData.value
                    readonly property bool textChip: modelData.labelKey !== ""

                    width: option.textChip ? optionLabel.implicitWidth + Theme.space.xl * 2 : 40
                    height: 40

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shape.full
                        color: option.selected ? Theme.secondaryContainer : "transparent"
                        border.width: 1
                        border.color: option.selected ? Theme.primary : Theme.outlineVariant
                        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.stateLayer(option.selected
                                                    ? Theme.scheme.onSecondaryContainer
                                                    : Theme.scheme.onSurface,
                                                    Theme.stateHover)
                            opacity: optionHover.containsMouse ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: Theme.motionShort3 }
                            }
                        }
                    }

                    Text {
                        id: optionLabel

                        anchors.centerIn: parent
                        visible: option.textChip
                        text: I18n.tr(option.modelData.labelKey)
                        color: option.selected ? Theme.scheme.onSecondaryContainer
                                               : Theme.scheme.onSurfaceVariant
                        font: Theme.typeLabelLarge
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !option.textChip
                        text: option.modelData.glyph
                        color: option.selected ? Theme.scheme.onSecondaryContainer
                                               : Theme.scheme.onSurface
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.md
                    }

                    MouseArea {
                        id: optionHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(option.modelData.value)
                    }
                }
            }
        }
    }
}
