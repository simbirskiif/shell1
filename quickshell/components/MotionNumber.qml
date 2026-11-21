import QtQuick
import "../singletons"

// Числовая анимация в токенах Material 3: длительность и кривая берутся
// из темы, поэтому все переходы в оболочке выглядят единообразно.
// curve по умолчанию — emphasized, для входа берут emphasizedDecelerate,
// для выхода — emphasizedAccelerate.
NumberAnimation {
    property var curve: Theme.curveEmphasized
    duration: Theme.motionMedium2
    easing.type: Easing.Bezier
    easing.bezierCurve: curve
}
