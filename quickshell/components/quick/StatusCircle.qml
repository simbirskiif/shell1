import QtQuick
import "../../singletons"

// Кружок-переключатель слева в плитке: заливка и иконка зависят
// от состояния, по нажатию — короткий отклик масштабом.
Item {
    id: root

    required property string icon
    required property bool active

    signal toggled()

    implicitWidth: Theme.quickCircleSize
    implicitHeight: Theme.quickCircleSize

    Rectangle {
        id: circle
        anchors.fill: parent
        radius: width / 2
        color: root.active ? Theme.accent : Theme.quickCircleOff
        Behavior on color { ColorAnimation { duration: Theme.quickViewDuration } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.quickIconOn : Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 16
            Behavior on color { ColorAnimation { duration: Theme.quickViewDuration } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.toggled();
            pressAnim.restart();
        }
    }

    SequentialAnimation {
        id: pressAnim
        NumberAnimation {
            target: circle
            property: "scale"
            to: 0.85
            duration: 70
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: circle
            property: "scale"
            to: 1
            duration: Theme.quickViewDuration
            easing.type: Easing.OutBack
        }
    }
}
