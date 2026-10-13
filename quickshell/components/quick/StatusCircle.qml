import QtQuick
import ".."
import "../../singletons"

// Кружок-переключатель слева в плитке: заливка и иконка зависят
// от состояния, по нажатию — короткий отклик масштабом.
Item {
    id: root

    required property string icon
    required property bool active

    // Иконка Wi-Fi с делениями вместо обычного глифа.
    property bool wifiStatus: false

    // В режиме редактирования кружок не переключает состояние.
    property bool interactive: true

    signal toggled()

    implicitWidth: Theme.quickCircleSize
    implicitHeight: Theme.quickCircleSize

    Rectangle {
        id: circle
        anchors.fill: parent
        radius: width / 2
        color: root.active ? Theme.accent : Theme.quickCircleOff
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

        Text {
            anchors.centerIn: parent
            visible: !root.wifiStatus
            text: root.icon
            color: root.active ? Theme.quickIconOn : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 16
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        WifiStatusIcon {
            anchors.centerIn: parent
            visible: root.wifiStatus
            width: 20
            height: 20
            onAccent: root.active
            offMode: !NetworkService.wifiEnabled
            signal: NetworkService.connectedSignal
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.toggled();
            pressAnim.restart();
        }
    }

    // m3: нажатие уходит вниз быстро, отпускание — мягко обратно.
    SequentialAnimation {
        id: pressAnim
        MotionNumber {
            target: circle
            property: "scale"
            to: 0.9
            duration: 100
            curve: Theme.curveStandardAccelerate
        }
        MotionNumber {
            target: circle
            property: "scale"
            to: 1
            duration: Theme.motionMedium1
            curve: Theme.curveEmphasizedDecelerate
        }
    }
}
