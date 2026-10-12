import QtQuick
import ".."
import "../../singletons"

// Батарейка: скруглённая колодка, поверх неё — полноразмерная заливка
// того же радиуса, которую слева-направо проявляет прямоугольная маска,
// поэтому правый край заливки всегда прямой: форму держит фигура,
// а не ширина заливки. Справа — носик батареи.
// Размер задаётся через bodyWidth/bodyHeight, цвет — по состоянию.
Item {
    id: root

    required property int level
    required property bool charging

    property real bodyWidth: 27
    property real bodyHeight: 14
    property real bodyRadius: root.bodyHeight * 0.32
    property real nubWidth: 2.5
    property real nubHeight: root.bodyHeight * 0.42

    readonly property bool low: root.level <= 15
    readonly property bool medium: !root.low && root.level <= 30

    readonly property color stateColor: {
        if (root.charging)
            return Theme.chargeColor;
        if (root.low)
            return Theme.lowColor;
        if (root.medium)
            return Theme.mediumColor;
        return Theme.quickText;
    }

    implicitWidth: root.bodyWidth + 1.5 + root.nubWidth
    implicitHeight: root.bodyHeight

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.bodyWidth
        height: root.bodyHeight
        radius: root.bodyRadius
        color: Theme.withAlpha(root.stateColor, 0.25)
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
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
            color: root.stateColor
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }
    }

    Rectangle {
        id: nub
        anchors.left: track.right
        anchors.leftMargin: 1.5
        anchors.verticalCenter: parent.verticalCenter
        width: root.nubWidth
        height: root.nubHeight
        radius: root.nubWidth / 2
        color: root.stateColor
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
    }
}
