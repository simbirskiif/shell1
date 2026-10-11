import QtQuick
import "../../singletons"

// Переключатель в стиле macOS: пилюля с уезжающим кружком.
Item {
    id: root

    required property bool checked

    signal toggled()

    implicitWidth: 42
    implicitHeight: 26

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.quickSwitchOff
        Behavior on color { ColorAnimation { duration: Theme.quickAnimDuration } }
    }

    Rectangle {
        id: knob
        width: 22
        height: 22
        y: 2
        x: root.checked ? track.width - width - 2 : 2
        radius: width / 2
        color: "#ffffff"
        Behavior on x {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
