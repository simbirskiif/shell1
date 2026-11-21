import QtQuick
import "../../singletons"

// Effects-пружина: прозрачность и цвет. Быстро, без перелёта —
// перелёт на opacity даёт мигание на границе 1.
SpringAnimation {
    spring: Theme.springs.effects.spring
    damping: Theme.springs.effects.damping
    epsilon: 0.001
}
