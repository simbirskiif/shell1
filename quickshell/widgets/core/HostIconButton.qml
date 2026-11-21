import QtQuick
import "../../components/expressive"
import "../../singletons"

// Кнопка управления карточкой в редакторе (M3 Expressive icon button).
// Живёт поверх обоев, поэтому подложка непрозрачная. Круг в покое при
// наведении превращается в «печенье» primary-контейнера, при нажатии
// сжимается и становится squircle; пружины дают живой отклик.
Item {
    id: root

    property string text: ""
    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    width: 38
    height: 38

    scale: root.pressed ? 0.88 : (root.hovered ? 1.08 : 1)
    Behavior on scale { SpringSpatial {} }

    MorphShape {
        anchors.fill: parent
        shape: root.pressed ? "squircle"
             : root.hovered ? "cookie"
             : "circle"
        modulation: 0.65
        color: root.hovered ? Theme.primaryContainer : Theme.menuSurface
        borderWidth: root.hovered ? 0 : 1
        borderColor: Theme.outlineVariant
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.centerIn: parent
        color: root.hovered ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
        font.family: Theme.fontFamily
        font.pixelSize: root.hovered ? Theme.iconSize.md : Theme.iconSize.sm + 2
        text: root.text
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
