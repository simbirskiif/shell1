import QtQuick
import "quick"
import "../singletons"

// Кнопка одного действия в баре: Wi-Fi, Bluetooth, яркость или звук.
// Внешний вид повторяет соседние кнопки; состояние берётся из сервисов
// (SystemIcons), а нажатие обрабатывает Bar.qml — у действий разная
// семантика: открыть панель или переключить radio.
Rectangle {
    id: root

    required property string kind // wifi | bluetooth | brightness | sound

    property bool wifiEnabled: true
    property bool wifiConnected: false
    property int wifiSignal: 0
    property bool bluetoothEnabled: true
    // Пользовательская иконка; пусто — штатный значок состояния.
    property string iconOverride: ""

    signal clicked()

    readonly property bool custom: root.iconOverride !== ""

    implicitWidth: content.implicitWidth + 24
    implicitHeight: Theme.iconButtonSize
    radius: Theme.controlRadius
    color: hover.containsMouse
           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
           : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Row {
        id: content

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        spacing: 8

        // --- Wi-Fi: живой значок сигнала либо выбранный глиф ---------------
        WifiStatusIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "wifi" && !root.custom
            width: 19
            height: 19
            glyphSize: 14
            offMode: !root.wifiEnabled
            signal: root.wifiSignal
            dim: !root.wifiConnected
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "wifi" && root.custom
            text: root.iconOverride
            color: root.wifiEnabled ? (root.wifiConnected ? Theme.scheme.onSurface
                                                          : Theme.scheme.onSurfaceVariant)
                                    : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
        }

        // --- Bluetooth: цвет показывает radio и подключение ----------------
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "bluetooth" && !root.custom
            text: SystemIcons.bluetoothGlyph
            color: SystemIcons.bluetoothColor
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "bluetooth" && root.custom
            text: root.iconOverride
            color: SystemIcons.bluetoothColor
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        // --- Яркость: солнце, насыщенность зависит от уровня ---------------
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "brightness" && !root.custom
            text: SystemIcons.brightnessGlyph
            color: SystemIcons.brightnessColor
            opacity: SystemIcons.brightnessOpacity
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "brightness" && root.custom
            text: root.iconOverride
            color: SystemIcons.brightnessColor
            opacity: SystemIcons.brightnessOpacity
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
        }

        // --- Звук: динамик/тихий/выключенный -------------------------------
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "sound" && !root.custom
            text: SystemIcons.soundGlyph
            color: SystemIcons.soundColor
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "sound" && root.custom
            text: root.iconOverride
            color: SystemIcons.soundColor
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }
    }

    // Точка подключённого Bluetooth-устройства: цвет значка мало заметен
    // на 16-пиксельном глифе.
    Rectangle {
        visible: root.kind === "bluetooth" && SystemIcons.bluetoothConnected
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.top: parent.top
        anchors.topMargin: 5
        width: 6
        height: 6
        radius: width / 2
        color: Theme.primary
        border.width: 1
        border.color: Theme.barBackground
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
