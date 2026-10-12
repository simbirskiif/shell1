import QtQuick
import ".."
import "../../singletons"

// Круглая иконка строки: значок сети или устройства.
// У подключённого элемента появляется обводка-кольцо, у Wi-Fi
// яркость значка зависит от уровня сигнала.
Item {
    id: root

    required property string icon
    required property bool connected
    property int strength: 0

    implicitWidth: 34
    implicitHeight: 34

    Rectangle {
        id: background
        anchors.fill: parent
        radius: width / 2
        color: root.connected ? Theme.quickTileActive : Theme.quickCircleOff
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: root.connected ? 1 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveStandard
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.connected ? Theme.accent : Theme.quickText
        opacity: root.strength > 0 ? 0.45 + 0.55 * (root.strength / 4) : 1
        font.family: Theme.iconFontFamily
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
    }
}
