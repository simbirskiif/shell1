import QtQuick
import "../../singletons"

// Сетка иконок для элемента бара. options — массив { glyph, label };
// пустой glyph означает «по умолчанию» (живой индикатор).
Item {
    id: root

    property var options: []
    property string selectedGlyph: ""

    signal picked(string glyph)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: flow.implicitHeight

    Flow {
        id: flow

        width: parent.width
        spacing: Theme.space.sm

        Repeater {
            model: root.options

            delegate: Item {
                id: cell

                required property var modelData

                readonly property bool selected: root.selectedGlyph === modelData.glyph

                width: 76
                height: 78

                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56
                    radius: Theme.shape.md
                    color: cell.selected ? Theme.secondaryContainer
                                        : Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: cell.selected ? Theme.primary : Theme.outlineVariant
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(cell.selected
                                                ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurface,
                                                Theme.stateHover)
                        opacity: cellHover.containsMouse ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.motionShort3 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.glyph !== "" ? cell.modelData.glyph : "\uf021"
                        color: cell.selected ? Theme.scheme.onSecondaryContainer
                                             : Theme.scheme.onSurface
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.lg
                    }
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 58
                    anchors.left: parent.left
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.modelData.label
                    color: cell.selected ? Theme.primary : Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelSmall
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: cellHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(cell.modelData.glyph)
                }
            }
        }
    }
}
