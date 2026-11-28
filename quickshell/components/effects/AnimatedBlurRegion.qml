import QtQuick
import Quickshell

// Регион blur, следящий за анимированной карточкой.
//
// Обычный `Region { item: card }` обновляется только по x/y/width/height
// и не замечает scale/transform: если карточка растёт из угла или
// выезжает, пятно blur остаётся на старой геометрии. Здесь геометрия
// считается через mapToItem и явные зависимости от scale/x/y, поэтому
// регион едет и масштабируется вместе с карточкой.
//
// opacity сюда не входит: у ext-background-effect-v1 нет альфы региона.
// Видимость региона включают снаружи:
//   BackgroundEffect.blurRegion: root.shown ? region : null
Region {
    id: root

    property Item target: null
    property real cornerRadius: 0

    readonly property real targetScale: root.target ? root.target.scale : 1

    // Явные чтения x/y/scale/width/height регистрируют зависимости биндинга:
    // mapToItem сам по себе не создаёт их для transform-свойств.
    readonly property rect targetRect: {
        if (!root.target)
            return Qt.rect(0, 0, 0, 0);

        const scale = root.target.scale;
        const localX = root.target.x;
        const localY = root.target.y;
        const point = root.target.mapToItem(null, 0, 0);

        return Qt.rect(Math.round(point.x), Math.round(point.y),
                       Math.round(root.target.width * scale),
                       Math.round(root.target.height * scale));
    }

    x: root.targetRect.x
    y: root.targetRect.y
    width: root.targetRect.width
    height: root.targetRect.height
    radius: Math.round(root.cornerRadius * root.targetScale)
}
