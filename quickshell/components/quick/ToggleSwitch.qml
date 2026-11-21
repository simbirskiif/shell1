import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Переключатель Material 3 Expressive: тяжёлая дорожка-пилюля, крупная
// ручка, которая меняет форму (круг ↔ squircle) и тянется при нажатии.
// Внутри ручки — галочка; включение читается и по форме, и по цвету.
Item {
    id: root

    required property bool checked

    signal toggled()

    implicitWidth: 60
    implicitHeight: 34

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    // Дорожка: включённая — primary, выключенная — тональная поверхность
    // с обводкой outline. Цвет — effects-переход, форма и ручка — пружины.
    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline
        scale: root.pressed ? 0.97 : 1

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.width { NumberAnimation { duration: 140 } }
        Behavior on scale {
            SpringSpatialFast {}
        }

        // Мягкое свечение-ореол при наведении: контейнер становится
        // заметнее, не превращаясь в тень.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: height / 2
            color: Theme.stateLayer(Theme.primary, 0.10)
            opacity: root.hovered ? 1 : 0
            z: -1
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // Ручка: сплющенный круг в покое, squircle во включённом состоянии.
    // При нажатии вытягивается по горизонтали — «живая» деформация.
    MorphShape {
        id: handle

        readonly property real restingSize: root.checked ? 26 : 22

        width: root.pressed ? handle.restingSize + 8 : handle.restingSize
        height: root.pressed ? handle.restingSize - 1 : handle.restingSize
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? track.width - width - 4 : 4
        shape: root.checked ? "squircle" : "circle"
        color: root.checked ? Theme.scheme.onPrimary : Theme.outline

        Behavior on width { SpringSpatial {} }
        Behavior on height { SpringSpatial {} }
        Behavior on x { SpringSpatial {} }

        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "\uf00c"
            color: Theme.primary
            font.family: Theme.iconFontFamily
            font.pixelSize: 12
            scale: root.checked ? 1 : 0.4
            Behavior on scale { SpringSpatialFast {} }
        }
    }


    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
