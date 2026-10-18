import QtQuick
import "../../singletons"

// Маленькая кнопка для карточек, каталога и попапа настроек.
Rectangle {
    id: root

    property string text: ""
    property bool active: false
    signal clicked()

    implicitWidth: label.implicitWidth + (root.text.length > 1 ? 18 : 12)
    implicitHeight: 26
    radius: 9
    color: root.active ? Theme.quickTileActive
           : (mouse.containsMouse ? Theme.quickTileHover : Theme.quickTile)
    border.width: 1
    border.color: root.active ? Theme.colors.primary : Theme.quickBorder

    Text {
        id: label

        anchors.centerIn: parent
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 11
        text: root.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
