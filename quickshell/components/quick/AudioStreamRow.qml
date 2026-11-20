import QtQuick
import ".."
import "../../singletons"

// Строка приложения в списке потоков: mute, название (приложение и то, что
// играет) и слайдер громкости этого потока.
Item {
    id: root

    // Узел PipeWire — поток воспроизведения. Громкость живёт в узле, поэтому
    // строка не хранит своё значение, а читает его из AudioService.
    required property var node

    readonly property bool muted: AudioService.hasAudio(root.node) ? root.node.audio.muted : false
    readonly property real value: AudioService.hasAudio(root.node) ? root.node.audio.volume : 0

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.listItemHeight
    height: implicitHeight

    // Кнопка-иконка m3: 40×40, круглая, hover — state layer on-surface.
    Rectangle {
        id: muteButton
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconButtonSize
        height: Theme.iconButtonSize
        radius: Theme.shape.full
        color: muteHover.containsMouse
               ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: root.muted ? "\uf026" : "\uf001"
            color: root.muted ? Theme.scheme.onSurfaceVariant : Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        MouseArea {
            id: muteHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: AudioService.setNodeMuted(root.node, !root.muted)
        }
    }

    Text {
        id: percent
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm
        width: Theme.space.xxxl
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyMedium
    }

    Text {
        id: label
        anchors.left: muteButton.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: percent.left
        anchors.rightMargin: Theme.space.md
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm
        text: AudioService.streamLabel(root.node)
        elide: Text.ElideRight
        color: Theme.scheme.onSurface
        font: Theme.typeBodyLarge
    }

    PanelSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.top: label.bottom
        height: Theme.iconSize.md
        value: root.value
        onMoved: v => AudioService.setNodeVolume(root.node, v)
    }
}
