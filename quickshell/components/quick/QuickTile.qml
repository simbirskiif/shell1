import QtQuick
import "../../singletons"

// Плитка быстрых настроек: кружок слева переключает состояние,
// остальная площадь раскрывает панель управления.
// Название и статус — одной строкой по центру, статус обрезается.
Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    required property bool active

    signal toggled()
    signal expandRequested()

    implicitWidth: Theme.quickWidth / 2
    implicitHeight: Theme.quickTileHeight
    radius: Theme.quickTileRadius
    color: root.active ? Theme.quickTileActive
                       : (hover.hovered ? Theme.quickTileHover : Theme.quickTile)
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expandRequested()
    }

    StatusCircle {
        id: circle
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        active: root.active
        onToggled: root.toggled()
    }

    Row {
        id: titleRow
        anchors.left: circle.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.subtitle !== ""
            text: "·"
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Text {
        anchors.left: titleRow.right
        anchors.leftMargin: titleRow.spacing
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.subtitle
        elide: Text.ElideRight
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
