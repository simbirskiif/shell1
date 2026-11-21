import QtQuick
import "."
import "../../singletons"

// FAB Material 3 Expressive: крупная форма-«печенье» с иконкой, которая
// при наведении и нажатии меняет форму и упруго сжимается. Цвет — либо
// primary-container, либо tertiary-container (два акцента в одной панели).
Item {
    id: root

    property string icon: "\uf013"
    property string tone: "primary"   // primary | tertiary | secondary
    property string shape: "cookie"
    property string hoverShape: "squircle"
    property int size: 56

    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property color container: root.tone === "tertiary" ? Theme.tertiaryContainer
                                     : root.tone === "secondary" ? Theme.secondaryContainer
                                     : Theme.primaryContainer
    readonly property color ink: root.tone === "tertiary" ? Theme.scheme.onTertiaryContainer
                                : root.tone === "secondary" ? Theme.scheme.onSecondaryContainer
                                : Theme.scheme.onPrimaryContainer

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    scale: root.pressed ? 0.9 : (root.hovered ? 1.04 : 1)
    Behavior on scale { SpringSpatial {} }

    MorphShape {
        anchors.fill: parent
        shape: root.hovered ? root.hoverShape : root.shape
        color: root.container
        borderWidth: 0
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.ink
        font.family: Theme.iconFontFamily
        font.pixelSize: root.size * 0.38
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
