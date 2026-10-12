import QtQuick
import ".."
import "../../singletons"

// Громкость: дорожка, заливка и кружок. Компонент «глупый» —
// значение приходит снаружи, наружу уходит сигнал moved.
Item {
    id: root

    required property real value

    signal moved(real v)

    implicitHeight: 22

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: height / 2
        color: Theme.quickCircleOff
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(track.height, track.width * root.value)
        height: track.height
        radius: track.radius
        color: Theme.accent
        Behavior on width {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveStandard
            }
        }
    }

    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * root.value - width / 2
        width: 16
        height: 16
        radius: width / 2
        color: "#ffffff"
        Behavior on x {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveStandard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.apply(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.apply(mouse.x);
        }
    }

    function apply(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }
}
