import QtQuick
import "../singletons"

// Кнопка справа в баре: статус Bluetooth / Wi-Fi / звука одной кнопкой.
Rectangle {
    id: root

    required property bool bluetoothEnabled
    required property bool wifiEnabled
    required property bool soundEnabled
    required property bool opened

    signal clicked()

    implicitWidth: content.implicitWidth + 22
    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: root.opened ? Theme.quickTileActive
                       : (hover.hovered ? Theme.quickTileHover : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: "\uf293"
            color: root.bluetoothEnabled ? Theme.quickText : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            text: "\uf1eb"
            color: root.wifiEnabled ? Theme.quickText : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            text: root.soundEnabled ? "\uf028" : "\uf026"
            color: root.soundEnabled ? Theme.quickText : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
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
