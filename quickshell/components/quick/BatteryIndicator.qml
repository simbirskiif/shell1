import QtQuick
import QtQuick.Shapes
import ".."
import "../expressive"
import "../../singletons"

// Батарейка в стиле Android 17, без процента внутри.
// Полупрозрачная колодка + заливка состояния, которую слева-направо
// проявляет маска (правый край заливки всегда прямой). Носик справа
// окрашен как колодка. При зарядке справа от батарейки появляется молния.
//
// Expressive: колодка — не прямоугольник с рамкой, а мягкая пилюля
// (MorphShape) с тональной обводкой; у зарядки появляется тёплое свечение,
// молния — tertiary-акцента и «пружинит» при появлении. API прежний.
Item {
    id: root

    required property int level
    required property bool charging

    property real bodyWidth: 28
    property real bodyHeight: 12
    property real bodyRadius: root.bodyHeight * 0.42
    property real nubWidth: 2
    property real nubHeight: root.bodyHeight * 0.4
    property real nubGap: 1.5
    property real boltGap: 3
    property real boltHeight: root.bodyHeight * 1.05
    property real boltWidth: root.boltHeight * 0.6

    readonly property bool low: root.level <= 15
    readonly property bool medium: !root.low && root.level <= 30

    // Цвет заливки: зарядка > низкий > средний > обычный — роли схемы m3.
    readonly property color fillColor: {
        if (root.charging)
            return Theme.success;
        if (root.low)
            return Theme.error;
        if (root.medium)
            return Theme.warning;
        return Theme.scheme.onSurface;
    }

    // Колодка и носик всегда нейтральные, как в Android 17: контур outline,
    // заливка состояния рисуется поверх него.
    readonly property color trackColor: Theme.outline

    // Не readonly: ширину слота под молнию анимирует Behavior ниже.
    property real boltSlot: root.charging ? root.boltGap + root.boltWidth : 0

    implicitWidth: root.bodyWidth + root.nubGap + root.nubWidth + root.boltSlot
    implicitHeight: Math.max(root.bodyHeight, root.boltHeight)

    // Мягкое свечение при зарядке: цвет держит состояние, а не обводка.
    Rectangle {
        anchors.left: track.left
        anchors.leftMargin: -Theme.space.xs
        anchors.verticalCenter: parent.verticalCenter
        width: track.width + Theme.space.sm
        height: root.bodyHeight + Theme.space.sm
        radius: height / 2
        color: Theme.withAlpha(root.fillColor, 0.22)
        opacity: root.charging ? 1 : 0
        z: -1
        Behavior on opacity { SpringEffects {} }
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Колодка: мягкая пилюля с тонкой обводкой (без жёсткого прямоугольника).
    MorphShape {
        id: track
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.bodyWidth
        height: root.bodyHeight
        shape: "pill"
        color: "transparent"
        modulation: 1
        borderWidth: root.bodyHeight > 20 ? 1.5 : 1
        borderColor: root.trackColor
    }

    Item {
        id: reveal
        anchors.left: track.left
        anchors.verticalCenter: parent.verticalCenter
        width: track.width * Math.max(0, Math.min(1, root.level / 100))
        height: track.height
        clip: true

        Behavior on width { SpringSpatial {} }

        MorphShape {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: track.width
            height: track.height
            shape: "pill"
            color: root.fillColor
            modulation: 1

            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    Rectangle {
        id: nub
        anchors.left: track.right
        anchors.leftMargin: root.nubGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.nubWidth
        height: root.nubHeight
        radius: root.nubWidth / 2
        color: root.trackColor
    }

    // Молния справа от батарейки (только при зарядке) — tertiary-акцент:
    // второй цвет в батарейной группе, а не ещё один нейтральный.
    Shape {
        id: bolt
        anchors.left: nub.right
        anchors.leftMargin: root.boltGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.boltWidth
        height: root.boltHeight
        opacity: root.charging ? 1 : 0
        visible: opacity > 0.01
        scale: root.charging ? 1 : 0.4
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatial {} }

        ShapePath {
            fillColor: Theme.tertiary
            strokeColor: "transparent"
            startX: bolt.width * 0.62; startY: 0
            PathLine { x: 0;                    y: bolt.height * 0.58 }
            PathLine { x: bolt.width * 0.45;    y: bolt.height * 0.58 }
            PathLine { x: bolt.width * 0.34;    y: bolt.height }
            PathLine { x: bolt.width;           y: bolt.height * 0.38 }
            PathLine { x: bolt.width * 0.54;    y: bolt.height * 0.38 }
            PathLine { x: bolt.width * 0.62;    y: 0 }
        }
    }
}
