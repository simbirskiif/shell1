import QtQuick
import "../expressive"
import "../../singletons"

// Главная кнопка плеера: circle в игре, squircle на паузе; морфинг идёт
// внутренней пружиной MorphShape, масштаб — SpatialFast.
Item {
    id: play

    property bool playing: false
    property bool enabled: true
    property color baseColor: Theme.primary
    property color inkColor: Theme.scheme.onPrimary

    signal clicked()

    readonly property bool hovered: playMouse.containsMouse

    width: 64
    height: 64
    opacity: play.enabled ? 1 : Theme.disabledContent
    scale: playMouse.pressed && play.enabled ? 0.90 : (play.hovered && play.enabled ? 1.05 : 1)
    Behavior on scale { SpringSpatialFast {} }

    MorphShape {
        anchors.fill: parent
        shape: play.playing ? "circle" : "squircle"
        color: play.baseColor
    }

    MorphShape {
        anchors.fill: parent
        shape: play.playing ? "circle" : "squircle"
        color: Theme.stateLayer(play.inkColor, Theme.stateHover)
        opacity: play.hovered && play.enabled ? 1 : 0
        Behavior on opacity { SpringEffects {} }
    }

    Text {
        anchors.centerIn: parent
        text: play.playing ? "\uf04c" : "\uf04b"
        color: play.inkColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.lg
    }

    MouseArea {
        id: playMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: play.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: play.clicked()
    }
}
