import QtQuick
import "../../singletons"

// Строка сети Wi-Fi: значок сети слева, имя, замок у закрытых сетей.
// Используется и для доступных, и для сохранённых сетей.
Rectangle {
    id: root

    required property string name
    required property int strength
    required property bool secured
    required property bool connected

    signal activated()

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.quickRowHeight
    color: rowHover.hovered ? Theme.quickTileHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    PanelIcon {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: "\uf1eb"
        connected: root.connected
        strength: root.strength
    }

    Text {
        anchors.left: iconSlot.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: root.secured
        text: "\uf023"
        color: Theme.quickTextDim
        font.family: Theme.iconFontFamily
        font.pixelSize: 12
    }
}
