import QtQuick
import ".."
import "../../singletons"

// Единый экран «модуль выключен»: показывается вместо списков,
// когда Wi-Fi/Bluetooth выключены.
Item {
    id: root

    required property string icon
    required property string title
    required property string description
    required property string actionText

    signal actionRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: 236

    Column {
        anchors.centerIn: parent
        width: parent.width - 56
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 34
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.description
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Item {
            width: 1
            height: 6
        }

        // Кнопка в стиле m3 filled button со state layer на ховере.
        Rectangle {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            width: buttonLabel.implicitWidth + 44
            height: 36
            radius: height / 2
            color: Theme.accent

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.quickIconOn
                opacity: buttonHover.hovered ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
            }

            Text {
                id: buttonLabel
                anchors.centerIn: parent
                text: root.actionText
                color: Theme.quickIconOn
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
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
