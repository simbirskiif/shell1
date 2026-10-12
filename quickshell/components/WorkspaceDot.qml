import QtQuick
import "../singletons"

// Точка одного рабочего стола. Активный больше и ярче;
// смена размера, цвета и позиции анимируется.
Rectangle {
    id: root

    required property var workspace

    readonly property bool active: workspace.active

    width: active ? Theme.workspaceActiveDotSize : Theme.workspaceDotSize
    height: width
    radius: width / 2
    color: active ? Theme.workspaceActiveColor : Theme.workspaceInactiveColor

    Behavior on width {
        MotionNumber {
            duration: Theme.motionShort4
            curve: Theme.curveStandard
        }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.motionShort3 }
    }

    // Соседние точки разъезжаются при смене активного стола.
    Behavior on x {
        MotionNumber {
            duration: Theme.motionShort4
            curve: Theme.curveStandard
        }
    }
}
