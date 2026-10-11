import QtQuick
import "../../singletons"

// Шапка внутренней панели: кнопка «назад», название и переключатель.
Item {
    id: root

    required property string title
    required property bool checked

    signal backRequested()
    signal toggled()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.quickHeaderHeight
    height: implicitHeight

    Rectangle {
        id: backButton
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: width / 2
        color: backHover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "\uf053"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }
    }

    Text {
        anchors.left: backButton.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    ToggleSwitch {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: root.toggled()
    }
}
