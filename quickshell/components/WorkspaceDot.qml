import QtQuick
import "expressive"
import "../singletons"

// Индикатор рабочего стола: неактивный — маленький круг, активный —
// вытянутая пилюля другого цвета. Ширина и форма едут на пружине,
// поэтому переключение читается движением, а не только цветом.
MorphShape {
    id: root

    required property var workspace

    readonly property bool active: workspace.active

    width: active ? 22 : 8
    height: 8
    shape: active ? "pill" : "circle"
    color: active ? Theme.primary : Theme.workspaceInactiveColor

    Behavior on width { SpringSpatial {} }
    Behavior on height { SpringSpatial {} }
}
