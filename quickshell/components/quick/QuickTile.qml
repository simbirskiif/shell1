import QtQuick
import "../../singletons"

// Плитка в списке быстрых настроек: слева кружок-переключатель,
// остальная площадь раскрывает панель управления.
Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    required property bool active

    signal toggled()
    signal expandRequested()

    implicitHeight: Theme.quickTileHeight
    width: parent ? parent.width : implicitWidth
    radius: Theme.quickTileRadius
    color: root.active ? Theme.quickTileActive
                       : (hover.hovered ? Theme.quickTileHover : Theme.quickTile)
    Behavior on color { ColorAnimation { duration: Theme.quickAnimDuration } }

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
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        active: root.active
        onToggled: root.toggled()
    }

    Column {
        anchors.left: circle.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text: root.title
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        Text {
            text: root.subtitle
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf054"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
