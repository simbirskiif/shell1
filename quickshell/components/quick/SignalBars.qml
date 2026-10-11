import QtQuick
import "../../singletons"

// Полоски уровня сигнала Wi-Fi: 4 столбика, заполненные по strength.
Item {
    id: root

    required property int strength

    implicitWidth: 18
    implicitHeight: 14

    Row {
        id: bars
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: 2

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: 3
                height: 4 + index * 3
                y: bars.height - height
                radius: 1
                color: index < root.strength ? Theme.accent : Theme.quickTextDim
                Behavior on color { ColorAnimation { duration: Theme.quickAnimDuration } }
            }
        }
    }
}
