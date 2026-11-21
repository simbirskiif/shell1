import QtQuick
import "../../singletons"

// Быстрая spatial-пружина: нажатия, отклик на курсор, мелкие сдвиги.
SpringAnimation {
    spring: Theme.springs.spatialFast.spring
    damping: Theme.springs.spatialFast.damping
    epsilon: 0.001
}
