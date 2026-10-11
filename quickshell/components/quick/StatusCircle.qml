import QtQuick
import "../../singletons"

// Кружок-переключатель слева в плитке: заливка и иконка зависят
// от состояния, по нажатию — короткий отклик масштабом.
Item {
    id: root

    required property string icon
    required property bool active

    signal toggled()

    implicitWidth: 40
    implicitHeight: 40

    Rectangle {
        id: circle
        anchors.fill: parent
        radius: width / 2
        color: root.active ? Theme.accent : Theme.quickCircleOff
        Behavior on color { ColorAnimation { duration: Theme.quickAnimDuration } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.quickIconOn : Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 17
            Behavior on color { ColorAnimation { duration: Theme.quickAnimDuration } }
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
            duration: 90
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: circle
            property: "scale"
            to: 1
            duration: 180
            easing.type: Easing.OutBack
        }
    }
}
