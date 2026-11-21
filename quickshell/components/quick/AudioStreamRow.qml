import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка приложения в списке потоков: mute, название (приложение и то, что
// играет) и слайдер громкости этого потока.
//
// Expressive: строка группируется формой (hover — squircle), mute — крупный
// орб 40, который у заглушённого потока становится «печеньем» error-цвета.
Item {
    id: root

    // Узел PipeWire — поток воспроизведения. Громкость живёт в узле, поэтому
    // строка не хранит своё значение, а читает его из AudioService.
    required property var node

    readonly property bool muted: AudioService.hasAudio(root.node) ? root.node.audio.muted : false
    readonly property real value: AudioService.hasAudio(root.node) ? root.node.audio.volume : 0

    readonly property bool hovered: rowHover.containsMouse

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 68
    height: implicitHeight

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    MorphShape {
        anchors.fill: parent
        anchors.topMargin: Theme.space.xs / 2
        anchors.bottomMargin: Theme.space.xs / 2
        shape: "squircle"
        color: root.muted ? Theme.withAlpha(Theme.errorContainer, 0.5)
             : root.hovered ? Theme.surfaceContainerHigh
             : "transparent"
        modulation: 0.35

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Кнопка-mute: крупный орб, у заглушённого потока — «печенье».
    MorphShape {
        id: muteButton
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        shape: root.muted ? "cookie" : (muteHover.containsMouse ? "squircle" : "circle")
        color: root.muted ? Theme.errorContainer
             : muteHover.containsMouse ? Theme.primaryContainer
             : Theme.surfaceContainerHighest
        modulation: 1

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: root.muted ? "\uf026" : "\uf001"
            color: root.muted ? Theme.scheme.onErrorContainer
                 : muteHover.containsMouse ? Theme.scheme.onPrimaryContainer
                 : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
            Behavior on color { ColorAnimation { duration: 140 } }
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
        anchors.topMargin: Theme.space.sm + 2
        width: Theme.space.xxxl
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
        color: root.muted ? Theme.scheme.onSurfaceVariant : Theme.tertiary
        font: Theme.typeEmphasizedLabelLarge
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: label
        anchors.left: muteButton.right
        anchors.leftMargin: Theme.space.md
        anchors.right: percent.left
        anchors.rightMargin: Theme.space.md
        anchors.top: parent.top
        anchors.topMargin: Theme.space.sm + 2
        text: AudioService.streamLabel(root.node)
        elide: Text.ElideRight
        color: Theme.scheme.onSurface
        font: Theme.typeLabelLarge
    }

    // Слайдер потока — тот же Expressive-слайдер, что и у громкости.
    PanelSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: Theme.space.md
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.xs
        height: 18
        accent: Theme.primary
        value: root.value
        onMoved: v => AudioService.setNodeVolume(root.node, v)
    }

}
