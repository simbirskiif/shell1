import QtQuick
import "../../singletons"

// Строка «подпись — значение» в панели (секция Details).
// Строка с пустым значением не показывается и не занимает высоту:
// вызывающий просто передаёт то, что есть, без своей логики.
Item {
    id: root

    required property string label
    required property string value

    readonly property bool shown: root.value !== ""

    visible: root.shown
    implicitWidth: parent ? parent.width : 0
    implicitHeight: root.shown ? Theme.quickRowHeight : 0
    height: implicitHeight

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyMedium
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: Theme.scheme.onSurface
        font: Theme.typeTitleSmall
    }
}
