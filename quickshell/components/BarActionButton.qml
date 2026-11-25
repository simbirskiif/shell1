import QtQuick
import "quick"
import "../singletons"

// Кнопка одного быстрого действия в баре: Wi-Fi, Bluetooth или яркость.
// Внешний вид повторяет соседние кнопки бара; нажатие обрабатывает Bar.qml,
// потому что у действий разная семантика (тумблер радио или открытие панели).
Rectangle {
    id: root

    required property string kind // wifi | bluetooth | brightness

    property bool wifiEnabled: true
    property bool wifiConnected: false
    property int wifiSignal: 0
    property bool bluetoothEnabled: true
    // Пользовательская иконка; пусто — штатный вид действия.
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

        // Wi-Fi: живой значок сигнала либо выбранный глиф.
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

        // Bluetooth: значок есть у Font Awesome; цвет показывает radio.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "bluetooth" && !root.custom
            text: "\uf293"
            color: root.bluetoothEnabled ? Theme.scheme.onSurface : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "bluetooth" && root.custom
            text: root.iconOverride
            color: root.bluetoothEnabled ? Theme.scheme.onSurface : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }

        // Яркость: солнце; действие открывает панель яркости.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "brightness" && !root.custom
            text: "\uf185"
            color: Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind === "brightness" && root.custom
            text: root.iconOverride
            color: Theme.scheme.onSurface
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.sm
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
