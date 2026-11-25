import QtQuick
import "../../singletons"

// Тональная карточка-группа настроек. Внутри — необязательный заголовок,
// пояснение и набор строк, переданных дочерними объектами.
Rectangle {
    id: root

    property string title: ""
    property string description: ""

    default property alias content: bodyColumn.data

    implicitWidth: parent ? parent.width : 0
    implicitHeight: contentColumn.implicitHeight + Theme.space.lg * 2
    width: implicitWidth
    height: implicitHeight
    radius: Theme.shape.lg
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outlineVariant

    Column {
        id: contentColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space.lg
        spacing: Theme.space.sm

        Text {
            width: parent.width
            visible: root.title !== ""
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeTitleSmall
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }

        Column {
            id: bodyColumn

            width: parent.width
            spacing: Theme.space.xs
        }
    }
}
