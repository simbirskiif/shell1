import QtQuick
import "../expressive"
import "../../singletons"

// Иконка плеера в баре: при включённом спектре и играющем треке показывает
// живые полосы, иначе — выбранный глиф или нотку. Клик открывает окно.
Rectangle {
    id: root

    property string iconOverride: ""

    signal clicked()

    readonly property bool showSpectrum: SpectrumService.enabled
    readonly property color contentColor: SpectrumService.playing
                                          ? Theme.primary
                                          : (SpectrumService.hasPlayer
                                             ? Theme.scheme.onSurface
                                             : Theme.scheme.onSurfaceVariant)

    implicitWidth: Theme.barIconSlot
    implicitHeight: Theme.barIconSlot
    radius: Theme.controlRadius
    color: hover.containsMouse
           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
           : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    SpectrumBars {
        anchors.centerIn: parent
        width: 22
        height: 16
        opacity: root.showSpectrum ? 1 : 0
        scale: root.showSpectrum ? 1 : 0.82
        visible: opacity > 0.01
        bands: SpectrumService.displayBands
        bars: 4
        gap: 2
        centered: true
        minBarHeight: 3
        barColor: SpectrumService.playing ? Theme.primary
                                          : Theme.scheme.onSurfaceVariant
        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatialFast {} }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        opacity: root.showSpectrum ? 0 : 1
        scale: root.showSpectrum ? 0.82 : 1
        visible: opacity > 0.01
        text: root.iconOverride !== "" ? root.iconOverride : "\uf001"
        color: root.contentColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        Behavior on opacity { SpringEffects {} }
        Behavior on scale { SpringSpatialFast {} }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
