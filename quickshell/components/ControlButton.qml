import QtQuick
import "quick"
import "../singletons"

// Кнопка справа в баре: статус Bluetooth / Wi-Fi / звука одной кнопкой.
Rectangle {
    id: root

    required property bool bluetoothEnabled
    required property bool wifiEnabled
    // Состояние Wi-Fi: подключён ли и насколько силён сигнал (для делений).
    required property bool wifiConnected
    required property int wifiSignal
    required property bool soundEnabled
    required property bool opened

    signal clicked()

    // M3: кнопка-пилюля 40dp высотой, состояние — filled tonal.
    implicitWidth: content.implicitWidth + 24
    implicitHeight: Theme.iconButtonSize
    radius: Theme.controlRadius
    color: root.opened ? Theme.secondaryContainer
                       : (hover.hovered ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                        : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Row {
        id: content
        anchors.centerIn: parent
        // глифы тоже сидят выше центра строки — выравниваем с батареей
        anchors.verticalCenterOffset: 1
        spacing: 10

        Text {
            text: "\uf293"
            color: root.bluetoothEnabled ? (root.opened ? Theme.scheme.onSecondaryContainer
                                                       : Theme.scheme.onSurface)
                                        : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        // Выключенное radio — перечёркнутый значок, включённое — деления
        // доступности.
        WifiStatusIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 19
            height: 19
            glyphSize: 14
            offMode: !root.wifiEnabled
            signal: root.wifiSignal
            dim: !root.wifiEnabled
        }

        Text {
            text: root.soundEnabled ? "\uf028" : "\uf026"
            color: root.soundEnabled ? (root.opened ? Theme.scheme.onSecondaryContainer
                                                   : Theme.scheme.onSurface)
                                    : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
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
