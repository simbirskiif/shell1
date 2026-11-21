import QtQuick
import "../singletons"

// Индикатор рабочего стола в духе M3: активный — вытянутая пилюля
// primary, остальные — точки на outline-variant. Смена формы и цвета
// анимируется, соседние точки разъезжаются.
Rectangle {
    id: root

    required property var workspace

    readonly property bool active: workspace.active

    width: active ? Theme.workspaceActiveDotSize : Theme.workspaceDotSize
    height: Theme.workspaceDotSize
    radius: height / 2
    color: active ? Theme.workspaceActiveColor
                  : Theme.withAlpha(Theme.workspaceInactiveColor, 0.85)

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
