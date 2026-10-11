import QtQuick
import "../../singletons"

// Плитка быстрых настроек: кружок слева переключает состояние,
// остальная площадь раскрывает панель управления.
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
    Behavior on color { ColorAnimation { duration: Theme.quickHoverDuration } }

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
        anchors.top: parent.top
        anchors.topMargin: 10
        icon: root.icon
        active: root.active
        onToggled: root.toggled()
    }

    Text {
        anchors.left: circle.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: circle.verticalCenter
        text: root.title
        elide: Text.ElideRight
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: circle.bottom
        anchors.topMargin: 8
        text: root.subtitle
        elide: Text.ElideRight
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: circle.verticalCenter
        text: "\uf054"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
