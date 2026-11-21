import QtQuick
import "../singletons"

// Движение в Material 3 Expressive — это пружина, а не длительность с
// кривой. Поэтому MotionNumber теперь SpringAnimation: существующие вызовы
// с duration/curve продолжают работать (свойства принимаются ради
// совместимости), но движение задаёт физика spatial-пружины.
// Для прозрачности и цвета используйте SpringEffects — там нет перелёта.
SpringAnimation {
    // Легаси-параметры: игнорируются, оставлены, чтобы не переписывать
    // сотни вызовов сразу.
    property var curve: null
    property real legacyDuration: 0

    spring: Theme.springs.spatial.spring
    damping: Theme.springs.spatial.damping
    epsilon: 0.001
}
