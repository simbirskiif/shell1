import QtQuick
import "quick"
import "expressive"
import "../singletons"

// Кластер статуса в баре: Bluetooth, Wi-Fi и звук одной пилюлей.
// В Expressive это плотная «таблетка» с жирными иконками; при открытой
// панели она заливается secondary-container и меняет контур.
Item {
    id: root

    required property bool bluetoothEnabled
    required property bool wifiEnabled
    required property bool wifiConnected
    required property int wifiSignal
    required property bool soundEnabled
    required property bool opened

    signal clicked()

    implicitWidth: content.implicitWidth + 26
    implicitHeight: 40

    readonly property bool hovered: hover.containsMouse

    scale: hover.pressed ? 0.94 : (root.hovered ? 1.05 : 1)
    Behavior on scale { SpringSpatialFast {} }

    MorphShape {
        anchors.fill: parent
        shape: "pill"
        color: root.opened ? Theme.secondaryContainer
             : root.hovered ? Theme.surfaceContainerHighest
             : Theme.withAlpha(Theme.surfaceContainerHigh, 0.55)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 9

        Text {
            text: "\uf293"
            color: root.bluetoothEnabled ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 18
        }

        WifiStatusIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            glyphSize: 18
            offMode: !root.wifiEnabled
            signal: root.wifiSignal
            dim: !root.wifiConnected
        }

        Text {
            text: root.soundEnabled ? "\uf028" : "\uf026"
            color: root.soundEnabled ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 18
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
