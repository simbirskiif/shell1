import QtQuick
import ".."
import "../../singletons"

// Единый экран «модуль выключен»: показывается вместо списков,
// когда Wi-Fi/Bluetooth выключены.
Item {
    id: root

    required property string icon
    // Своя иконка вместо глифа (например индикатор Wi-Fi с делениями).
    property bool wifiIcon: false
    required property string title
    required property string description
    required property string actionText
    // Кнопка скрывается, когда действие невозможно: например, Wi-Fi
    // заблокирован аппаратным переключателем и включить его нельзя.
    property bool showAction: true

    signal actionRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: Theme.space.xxxl * 5

    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.space.xxxl - Theme.space.sm
        spacing: Theme.space.sm

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.wifiIcon
            text: root.icon
            color: Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.xl
        }

        WifiStatusIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.wifiIcon
            width: Theme.iconSize.xl + Theme.space.sm
            height: Theme.iconSize.xl + Theme.space.sm
            glyphSize: Theme.iconSize.xl
            offMode: true
            dim: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Theme.scheme.onSurface
            font: Theme.typeTitleMedium
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.description
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }

        Item {
            width: 1
            height: root.showAction ? Theme.space.sm : 0
        }

        // Кнопка m3 filled button: пилюля primary, hover — state layer on-primary.
        Rectangle {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            width: buttonLabel.implicitWidth + Theme.space.xl * 2
            height: root.showAction ? Theme.buttonHeight : 0
            visible: root.showAction
            radius: Theme.shape.full
            color: Theme.primary

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.stateLayer(Theme.scheme.onPrimary, Theme.stateHover)
                opacity: buttonHover.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                id: buttonLabel
                anchors.centerIn: parent
                text: root.actionText
                color: Theme.scheme.onPrimary
                font: Theme.typeLabelLarge
            }

            MouseArea {
                id: buttonHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionRequested()
            }
        }
    }
}
