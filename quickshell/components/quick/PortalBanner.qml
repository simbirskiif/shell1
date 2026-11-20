import QtQuick
import ".."
import "../../singletons"

// Баннер captive portal в стиле M3: тональный контейнер со скруглением
// medium, иконка, пояснение и текстовая кнопка. Показывается в панели
// «Интернет» над списком сетей.
Item {
    id: root

    signal signInRequested()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        anchors.topMargin: Theme.space.xs
        anchors.bottomMargin: Theme.space.xs
        radius: Theme.shape.md
        color: Theme.secondaryContainer

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.stateLayer(Theme.scheme.onSecondaryContainer, Theme.stateHover)
            opacity: bannerHover.containsMouse ? 1 : 0
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
            anchors.leftMargin: Theme.space.lg
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0ac"
            color: Theme.scheme.onSecondaryContainer
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
        }

        Text {
            anchors.left: bannerIcon.right
            anchors.leftMargin: Theme.space.md
            anchors.right: bannerAction.left
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: "Войти в сеть"
            color: Theme.scheme.onSecondaryContainer
            font: Theme.typeLabelLarge
        }

        Text {
            id: bannerAction
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.lg
            anchors.verticalCenter: parent.verticalCenter
            text: "Открыть"
            color: Theme.scheme.onSecondaryContainer
            font: Theme.typeLabelLarge
        }
    }
}
