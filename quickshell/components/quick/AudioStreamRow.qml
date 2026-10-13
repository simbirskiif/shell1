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
    implicitHeight: 56
    height: implicitHeight

    Rectangle {
        id: muteButton
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: width / 2
        color: muteHover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            anchors.centerIn: parent
            text: root.muted ? "\uf026" : "\uf001"
            color: root.muted ? Theme.quickTextDim : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
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
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 42
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Text {
        anchors.left: muteButton.right
        anchors.leftMargin: 10
        anchors.right: percent.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 10
        text: AudioService.streamLabel(root.node)
        elide: Text.ElideRight
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    PanelSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 32
        height: 18
        value: root.value
        onMoved: v => AudioService.setNodeVolume(root.node, v)
    }
}
