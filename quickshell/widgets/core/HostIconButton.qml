import QtQuick
import "../../singletons"

// Круглая кнопка управления карточкой в редакторе. Живёт поверх обоев,
// поэтому в отличие от кнопок внутри панелей имеет непрозрачную подложку.
Rectangle {
    id: root

    property string text: ""
    signal clicked()

    width: 30
    height: 30
    radius: width / 2
    color: mouse.containsMouse ? Theme.menuSurfaceHover : Theme.menuSurface
    border.width: 1
    border.color: mouse.containsMouse ? Theme.colors.primary : Theme.menuBorder


    Text {
        anchors.centerIn: parent
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        text: root.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
