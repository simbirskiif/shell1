import QtQuick
import "../../singletons"

// Кнопка Material 3 для окна настроек: filled / tonal / outlined / text.
// Ширина по содержимому, высота 40 — как у остальных действий оболочки.
Item {
    id: root

    property string text: ""
    property string variant: "tonal" // filled | tonal | outlined | text
    property bool enabled: true

    signal clicked()

    implicitWidth: label.implicitWidth + Theme.space.xl * 2
    implicitHeight: Theme.buttonHeight
    width: implicitWidth
    height: implicitHeight
    opacity: root.enabled ? 1 : Theme.disabledContent

    readonly property bool filled: root.variant === "filled"
    readonly property bool tonal: root.variant === "tonal"
    readonly property bool outlined: root.variant === "outlined"
    readonly property color background: root.filled ? Theme.primary
                                       : root.tonal ? Theme.secondaryContainer
                                       : "transparent"
    readonly property color foreground: root.filled ? Theme.scheme.onPrimary
                                       : root.tonal ? Theme.scheme.onSecondaryContainer
                                       : Theme.primary

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.full
        color: root.background
        border.width: root.outlined ? 1 : 0
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.full
        color: Theme.stateLayer(root.foreground, hover.pressed
                                ? Theme.statePressed : Theme.stateHover)
        opacity: hover.containsMouse && root.enabled ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font: Theme.typeLabelLarge
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
