import QtQuick
import ".."
import "../../singletons"

// Батарея в стиле Android: нарисованная батарейка (обводка, заливка уровня,
// носик) и процент рядом с ней. Цвет зависит от состояния: зарядка —
// зелёный, <=15% — красный, <=30% — жёлтый. Нажатие открывает панель питания.
Item {
    id: root

    required property int level
    required property bool charging

    signal clicked()

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

    implicitWidth: content.implicitWidth + 18
    implicitHeight: 34

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // Батарейка: скруглённая колодка, поверх неё — полноразмерная
        // заливка того же радиуса, которую слева-направо «проявляет»
        // прямоугольная маска. Поэтому правый край заливки всегда прямой,
        // а форму держит сама фигура батареи, а не ширина заливки.
        Item {
            id: cell
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 14

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 27
                height: 14
                radius: 4.5
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
                width: 2.5
                height: 6
                radius: 1.25
                color: root.stateColor
                Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.level + "%"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.charging
            text: "\uf0e7"
            color: Theme.chargeColor
            font.family: Theme.iconFontFamily
            font.pixelSize: 11
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
