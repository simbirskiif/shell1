import QtQuick
import ".."
import "../../singletons"

// Строка-баннер captive portal: «подключено, но нужен вход».
// Показывается в панели «Интернет» над списком сетей.
Item {
    id: root

    signal signInRequested()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        anchors.margins: 0
        color: Theme.quickTileActive
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Rectangle {
            anchors.fill: parent
            color: Theme.quickIconOn
            opacity: bannerHover.hovered ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        MouseArea {
            id: bannerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.signInRequested()
        }

        Text {
            id: bannerIcon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0ac"
            color: Theme.accent
            font.family: Theme.iconFontFamily
            font.pixelSize: 15
        }

        Text {
            anchors.left: bannerIcon.right
            anchors.leftMargin: 12
            anchors.right: bannerAction.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: "Sign in to network"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Text {
            id: bannerAction
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "Open"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
