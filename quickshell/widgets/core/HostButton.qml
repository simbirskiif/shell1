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
    radius: 8
    color: root.active || mouse.containsMouse
           ? Theme.colors.primaryContainer : Theme.colors.surface
    border.width: 1
    border.color: root.active ? Theme.colors.primary : Theme.colors.outline

    Text {
        id: label

        anchors.centerIn: parent
        color: Theme.colors.onSurface
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
