import QtQuick
import "../../singletons"

// Spatial-пружина Expressive: позиция, размер, форма. Лёгкий перелёт
// (~8-10%) делает движение живым, но не разваливает раскладку.
SpringAnimation {
    spring: Theme.springs.spatial.spring
    damping: Theme.springs.spatial.damping
    epsilon: 0.001
}
