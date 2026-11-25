import QtQuick
import "../../singletons"

// Строка списка настроек: заголовок, пояснение и элемент управления справа.
// Управление передаётся дочерним объектом (default property), поэтому одна
// строка одинаково хорошо принимает переключатель, кнопки и сегменты.
Item {
    id: root

    property string title: ""
    property string description: ""

    default property alias control: controlSlot.data

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.listItemHeight,
                             textColumn.implicitHeight + Theme.space.md)

    Column {
        id: textColumn

        anchors.left: parent.left
        anchors.right: controlSlot.left
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
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
    }

    Item {
        id: controlSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
