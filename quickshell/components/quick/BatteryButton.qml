import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Батарея в баре: тональный чип с процентом emphasized-стилем.
// Наведение мягко поднимает чип, нажатие — сжимает.
Item {
    id: root

    required property int level
    required property bool charging
    property bool showPercent: true

    signal clicked()

    implicitWidth: content.implicitWidth + 22
    implicitHeight: 34

    readonly property bool hovered: mouse.containsMouse

    scale: mouse.pressed ? 0.94 : (root.hovered ? 1.04 : 1)
    Behavior on scale { SpringSpatialFast {} }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        BatteryIndicator {
            anchors.verticalCenter: parent.verticalCenter
            level: root.level
            charging: root.charging
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPercent
            text: root.level + "%"
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedLabelLarge
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
