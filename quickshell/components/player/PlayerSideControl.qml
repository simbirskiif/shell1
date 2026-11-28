import QtQuick
import "../expressive"
import "../../singletons"

// Вторичная кнопка плеера: тональная squircle-кнопка, которая при наведении
// морфится в круг. Размер — тач-минимум 48.
Item {
    id: side

    property string icon: ""
    property bool enabled: true
    property color baseColor: Theme.secondaryContainer
    property color inkColor: Theme.scheme.onSecondaryContainer

    signal clicked()

    readonly property bool hovered: sideMouse.containsMouse
    readonly property string shapeName: side.hovered && side.enabled ? "circle" : "squircle"

    width: Theme.touchTarget
    height: Theme.touchTarget
    opacity: side.enabled ? 1 : Theme.disabledContent
    scale: sideMouse.pressed && side.enabled ? 0.92 : (side.hovered && side.enabled ? 1.05 : 1)
    Behavior on scale { SpringSpatialFast {} }

    MorphShape {
        anchors.fill: parent
        shape: side.shapeName
        modulation: 0.45
        color: side.baseColor
    }

    MorphShape {
        anchors.fill: parent
        shape: side.shapeName
        modulation: 0.45
        color: Theme.stateLayer(side.inkColor, Theme.stateHover)
        opacity: side.hovered && side.enabled ? 1 : 0
        Behavior on opacity { SpringEffects {} }
    }

    Text {
        anchors.centerIn: parent
        text: side.icon
        color: side.inkColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
    }

    MouseArea {
        id: sideMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: side.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: side.clicked()
    }
}
