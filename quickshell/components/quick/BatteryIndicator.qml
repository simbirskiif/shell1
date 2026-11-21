import QtQuick
import QtQuick.Shapes
import ".."
import "../../singletons"

// Батарейка в стиле Android 17, без процента внутри.
// Полупрозрачная колодка + заливка состояния, которую слева-направо
// проявляет маска (правый край заливки всегда прямой). Носик справа
// окрашен как колодка. При зарядке справа от батарейки появляется молния.
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

    Behavior on boltSlot {
        MotionNumber {
            duration: Theme.motionShort4
            curve: Theme.curveEmphasized
        }
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.bodyWidth
        height: root.bodyHeight
        radius: root.bodyRadius
        color: "transparent"
        border.width: 1
        border.color: root.trackColor
    }

    Item {
        id: reveal
        anchors.left: track.left
        anchors.verticalCenter: parent.verticalCenter
        width: track.width * Math.max(0, Math.min(1, root.level / 100))
        height: track.height
        clip: true

        Behavior on width {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasized
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: track.width
            height: track.height
            radius: track.radius
            color: root.fillColor
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
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

    // Молния справа от батарейки (только при зарядке)
    Shape {
        id: bolt
        anchors.left: nub.right
        anchors.leftMargin: root.boltGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.boltWidth
        height: root.boltHeight
        opacity: root.charging ? 1 : 0
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer

        Behavior on opacity { NumberAnimation { duration: Theme.motionShort4 } }

        ShapePath {
            fillColor: Theme.scheme.onSurface
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
