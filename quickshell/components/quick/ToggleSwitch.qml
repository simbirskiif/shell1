import QtQuick
import ".."
import "../../singletons"

// Переключатель Material 3: дорожка-пилюля 52×32, ручка уезжает вправо и
// растёт. Выключенный — тональная поверхность с обводкой outline, включённый —
// primary с ручкой on-primary и галочкой.
Item {
    id: root

    required property bool checked

    signal toggled()

    implicitWidth: 52
    implicitHeight: 32

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        Behavior on border.width { NumberAnimation { duration: Theme.motionShort4 } }
    }

    Rectangle {
        id: handle
        width: root.checked ? 24 : 16
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? track.width - width - 4 : 8
        color: root.checked ? Theme.scheme.onPrimary : Theme.outline

        Behavior on x {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveEmphasized
            }
        }
        Behavior on width {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveEmphasized
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "\uf00c"
            color: Theme.primary
            font.family: Theme.iconFontFamily
            font.pixelSize: 12
            opacity: root.checked ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
