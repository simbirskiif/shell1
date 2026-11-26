import QtQuick
import "../../singletons"

// Иконка плеера в баре: при включённом спектре и играющем треке показывает
// живые полосы, иначе — выбранный глиф или нотку. Клик открывает окно.
Rectangle {
    id: root

    property string iconOverride: ""

    signal clicked()

    readonly property bool showSpectrum: SpectrumService.enabled
                                        && SpectrumService.playing
    readonly property color contentColor: SpectrumService.playing
                                          ? Theme.primary
                                          : (SpectrumService.hasPlayer
                                             ? Theme.scheme.onSurface
                                             : Theme.scheme.onSurfaceVariant)

    implicitWidth: Theme.iconButtonSize
    implicitHeight: Theme.iconButtonSize
    radius: Theme.controlRadius
    color: hover.containsMouse
           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
           : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    SpectrumBars {
        anchors.centerIn: parent
        visible: root.showSpectrum
        width: 20
        height: 16
        bands: SpectrumService.bands
        bars: 5
        gap: 1.2
        minBarHeight: 2
        barColor: Theme.primary
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        visible: !root.showSpectrum
        text: root.iconOverride !== "" ? root.iconOverride : "\uf001"
        color: root.contentColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
