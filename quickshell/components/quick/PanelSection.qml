import QtQuick
import "../../singletons"

// Заголовок секции внутри панели (m3 list section header).
Item {
    id: root

    required property string text

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.quickSectionHeight
    height: implicitHeight

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.primary
        font: Theme.typeLabelLarge
    }
}
