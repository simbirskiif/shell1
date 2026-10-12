import QtQuick
import ".."
import "../../singletons"

// Строка Bluetooth-устройства: значок устройства слева, подключённое
// обведено кольцом, справа — индикатор подключения.
Rectangle {
    id: root

    required property string name
    required property string icon
    required property bool connected
    required property bool connecting

    signal activated()

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.quickRowHeight
    color: rowHover.hovered && !root.connecting ? Theme.quickTileHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.connecting
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    PanelIcon {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        connected: root.connected
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

    LoadingIndicator {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        visible: root.connecting
    }
}
