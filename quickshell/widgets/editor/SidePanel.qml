import QtQuick
import "../../components/expressive"
import "../../singletons"

// Правая панель параметров: та же геометрия и материал, что у панелей
// оболочки (Theme.quick*). Живёт внутри DesktopLayer, отдельного окна нет.
//
// Expressive: панель — крупная morph-форма (squircle с приглушённой волной),
// выезжает и растворяется на пружинах, а не на длительностях с кривыми.
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

    Item {
        id: panel

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Math.min(Theme.quickWidth, parent.width)
        opacity: root.opened ? 1 : 0
        clip: true

        Behavior on opacity { SpringEffects {} }

        transform: Translate {
            id: slide

            x: root.opened ? 0 : panel.width

            Behavior on x { SpringSpatial {} }
        }

        // M3 side sheet поверх обоев: крупная форма листа. Для высокой панели
        // берём большой явный радиус, а не MorphShape: полярная форма на
        // боксе 420×1200 даёт чрезмерно круглые углы и «съедает» шапку.
        Rectangle {
            anchors.fill: parent
            topLeftRadius: Theme.shape.xlIncreased
            bottomLeftRadius: Theme.shape.xlIncreased
            topRightRadius: 0
            bottomRightRadius: 0
            color: Theme.panelSurface
            border.width: 0
        }

        Item {
            id: body

            anchors.fill: parent
            anchors.margins: Theme.space.lg
        }
    }
}
