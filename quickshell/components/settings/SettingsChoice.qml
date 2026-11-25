import QtQuick
import "../../singletons"

// Группа взаимоисключающих вариантов (M3 filter chips). options — массив
// объектов { key, label }; value — выбранный key.
Item {
    id: root

    property string title: ""
    property string description: ""
    property var options: []
    property string value: ""

    signal selected(string key)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: parent.width
        spacing: Theme.space.sm

        Text {
            width: parent.width
            visible: root.title !== ""
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeBodyLarge
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
            wrapMode: Text.WordWrap
        }

        Flow {
            width: parent.width
            spacing: Theme.space.sm

            Repeater {
                model: root.options

                delegate: Rectangle {
                    id: chip

                    required property var modelData

                    readonly property bool selected: root.value === modelData.key

                    width: chipLabel.implicitWidth + Theme.space.xl
                    height: 32
                    radius: Theme.shape.full
                    color: chip.selected ? Theme.secondaryContainer : "transparent"
                    border.width: 1
                    border.color: chip.selected ? Theme.secondaryContainer
                                                : Theme.outlineVariant
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(chip.selected
                                                ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurface,
                                                Theme.stateHover)
                        opacity: chipHover.containsMouse ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.motionShort3 }
                        }
                    }

                    Text {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.selected ? Theme.scheme.onSecondaryContainer
                                             : Theme.scheme.onSurfaceVariant
                        font: Theme.typeLabelLarge
                    }

                    MouseArea {
                        id: chipHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(chip.modelData.key)
                    }
                }
            }
        }
    }
}
