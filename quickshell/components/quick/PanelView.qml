import QtQuick
import ".."
import "../../singletons"

// Единая обёртка вида (основная сетка плиток и дочерние панели).
// Переход — m3 fade through: уходящий вид гаснет за первые 30% времени,
// приходящий проявляется и дорастает с 92% в оставшиеся 70%.
Item {
    id: root

    required property bool active

    // Жест возврата: gesture 0..1 (-1 — жест не идёт). Во время жеста вид
    // едет за пальцем: gestureShift -1 — уходит влево, +1 — приходит справа.
    property real gesture: -1
    property int gestureShift: -1

    default property alias content: host.data

    readonly property Item view: host.children.length > 0 ? host.children[0] : null

    implicitWidth: view ? view.implicitWidth : 0
    implicitHeight: view ? view.implicitHeight : 0

    visible: opacity > 0

    readonly property real gestureX: {
        if (root.gesture < 0)
            return 0;
        return root.gestureShift < 0 ? -root.gesture * root.width
                                     : (1 - root.gesture) * root.width;
    }

    // Смещение задаём трансформацией: anchors и x конфликтуют,
    // а transform — нет.
    transform: Translate { x: root.gestureX }

    states: [
        State {
            name: "shown"
            when: root.active
            PropertyChanges {
                target: root
                opacity: 1
                scale: 1
            }
        },
        State {
            name: "hidden"
            when: !root.active
            PropertyChanges {
                target: root
                opacity: 0
                scale: Theme.motionFadeThroughScale
            }
        }
    ]

    transitions: [
        Transition {
            to: "shown"
            SequentialAnimation {
                PauseAnimation { duration: Theme.motionMedium2 * Theme.motionFadeOutShare }
                MotionNumber {
                    properties: "opacity,scale"
                    duration: Theme.motionMedium2 * (1 - Theme.motionFadeOutShare)
                    curve: Theme.curveEmphasizedDecelerate
                }
            }
        },
        Transition {
            to: "hidden"
            MotionNumber {
                property: "opacity"
                duration: Theme.motionMedium2 * Theme.motionFadeOutShare
                curve: Theme.curveEmphasizedAccelerate
            }
        }
    ]

    Item {
        id: host
        anchors.fill: parent
    }
}
