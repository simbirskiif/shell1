import QtQuick
import "../../singletons"

// Строка Bluetooth-устройства: значок устройства слева (наушники, телефон,
// геймпад, клавиатура...), подключённое обведено кольцом.
// Используется и для доступных, и для сохранённых устройств.
Rectangle {
    id: root

    required property string name
    required property string icon
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
}
