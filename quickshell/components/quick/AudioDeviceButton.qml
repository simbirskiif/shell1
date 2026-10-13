import QtQuick
import ".."
import "../../singletons"

// Строка текущего устройства: подпись и стрелка «открыть список».
// Нажатие открывает отдельную панель выбора устройств.
Item {
    id: root

    required property string icon
    required property string text

    signal clicked()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.quickRowHeight
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: deviceHover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Text {
        id: iconText
        anchors.left: parent.left
        anchors.leftMargin: 21
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.quickTextDim
        font.family: Theme.iconFontFamily
        font.pixelSize: 13
    }

    Text {
        id: label
        anchors.left: iconText.right
        anchors.leftMargin: 12
        anchors.right: chevron.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.text !== "" ? root.text : "No device"
        elide: Text.ElideRight
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf054"
        color: Theme.quickTextDim
        font.family: Theme.iconFontFamily
        font.pixelSize: 11
    }

    MouseArea {
        id: deviceHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
