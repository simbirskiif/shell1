import QtQuick
import "../../singletons"

// Правая панель параметров: та же геометрия и материал, что у панелей
// оболочки (Theme.quick*). Живёт внутри DesktopLayer, отдельного окна нет.
Item {
    id: root

    property bool opened: false
    signal closed()

    default property alias content: body.data

    anchors.fill: parent
    z: 125
    visible: true

    // Клик мимо панели закрывает её, но не затемняет весь экран.
    MouseArea {
        anchors.fill: parent
        visible: root.opened
        onClicked: root.closed()
    }

    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Math.min(Theme.quickWidth, parent.width)
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder
        topLeftRadius: Theme.quickRadius
        bottomLeftRadius: Theme.quickRadius
        topRightRadius: 0
        bottomRightRadius: 0
        clip: true
        opacity: root.opened ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionShort4
                easing.type: Easing.OutCubic
            }
        }

        transform: Translate {
            id: slide

            x: root.opened ? 0 : panel.width

            Behavior on x {
                NumberAnimation {
                    duration: Theme.motionMedium2
                    easing.bezierCurve: Theme.curveEmphasized
                }
            }
        }

        Item {
            id: body

            anchors.fill: parent
            anchors.margins: Theme.quickPadding
        }
    }
}
