import QtQuick
import ".."
import "../../singletons"

// Слайдер Material 3: тонкая дорожка 4dp, активная часть primary,
// вертикальная ручка-«рукоятка» 4×24 с ореолом состояния при наведении.
// Компонент «глупый» — значение приходит снаружи, наружу уходит сигнал moved.
Item {
    id: root

    required property real value

    signal moved(real v)

    implicitHeight: 32

    readonly property real trackHeight: 4
    readonly property real handleHeight: mouse.containsMouse ? 28 : 24
    readonly property real handleX: Math.max(0, Math.min(width, track.width * root.value))

    // Неактивная дорожка: весь путь до конца.
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Theme.surfaceContainerHighest
    }

    // Активная часть — от начала до ручки.
    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.trackHeight, root.handleX)
        height: root.trackHeight
        radius: height / 2
        color: Theme.primary
        Behavior on width {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveStandard
            }
        }
    }

    // Конечная отметка M3: маленькая точка у правого края дорожки.
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: 4
        radius: 2
        color: Theme.outline
    }

    // Ореол состояния вокруг ручки (M3 state layer).
    Rectangle {
        width: 40
        height: 40
        radius: width / 2
        x: root.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.stateLayer(Theme.primary, Theme.stateHover)
        opacity: mouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    // Ручка: вертикальная пилюля, как в M3.
    Rectangle {
        id: knob
        width: 4
        height: root.handleHeight
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX - width / 2
        color: Theme.primary
        Behavior on height {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveEmphasized
            }
        }
        Behavior on x {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveStandard
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.apply(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.apply(event.x);
        }
    }

    function apply(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }
}
