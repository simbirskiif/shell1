import QtQuick
import "../../singletons"

// Круглая кнопка управления карточкой в редакторе (M3 icon button).
// Живёт поверх обоев, поэтому в отличие от кнопок внутри панелей имеет
// непрозрачную подложку; наведение — слоем состояния surfaceContainerHighest.
Rectangle {
    id: root

    property string text: ""
    signal clicked()

    width: 32
    height: 32
    radius: Theme.shape.full
    color: mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.menuSurface
    border.width: 1
    border.color: mouse.containsMouse ? Theme.primary : Theme.outlineVariant
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionShort3 } }

    Text {
        anchors.centerIn: parent
        color: Theme.scheme.onSurface
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize.sm
        text: root.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
