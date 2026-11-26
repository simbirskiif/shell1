import QtQuick
import "quick"
import "../singletons"

// Кнопка справа в баре: статус Bluetooth / Wi-Fi / звука одной кнопкой.
// Состав настраивается в окне настроек: каждый слот может быть живым
// (auto), скрытым (пусто) или заменён своим глифом. Если скрыты все три,
// кнопка показывает шестерёнку и остаётся входом в быстрые настройки.
Rectangle {
    id: root

    required property bool bluetoothEnabled
    required property bool wifiEnabled
    // Состояние Wi-Fi: подключён ли и насколько силён сигнал (для делений).
    required property bool wifiConnected
    required property int wifiSignal
    required property bool soundEnabled
    required property bool opened

    // "auto" — штатный значок, "" — слот скрыт, иначе глиф Nerd Font.
    property string bluetoothIcon: "auto"
    property string wifiIcon: "auto"
    property string soundIcon: "auto"

    readonly property bool allSlotsHidden: bluetoothIcon === "" && wifiIcon === ""
                                           && soundIcon === ""
    readonly property color activeColor: root.opened ? Theme.scheme.onSecondaryContainer
                                                      : Theme.scheme.onSurface
    readonly property color dimColor: root.opened
                                      ? Theme.stateLayer(Theme.scheme.onSecondaryContainer,
                                                         Theme.disabledContent)
                                      : Theme.quickTextDim

    signal clicked()

    // M3: кнопка-пилюля 40dp высотой, состояние — filled tonal.
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barIconSlot
    radius: Theme.controlRadius
    color: root.opened ? Theme.secondaryContainer
                       : (hover.containsMouse ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                        : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

    Row {
        id: content
        anchors.centerIn: parent
        // глифы тоже сидят выше центра строки — выравниваем с батареей
        anchors.verticalCenterOffset: 1
        spacing: Theme.barIconGap

        // Каждый значок — в своём слоте сетки бара: центры идут с шагом
        // 44, поэтому промежуток между значками статуса такой же, как до
        // соседних кнопок.
        // --- Bluetooth ----------------------------------------------------
        Item {
            width: Theme.barIconSlot
            height: Theme.barIconSlot
            visible: !root.allSlotsHidden && root.bluetoothIcon !== ""

            Text {
                anchors.centerIn: parent
                visible: root.bluetoothIcon === "auto"
                text: SystemIcons.bluetoothGlyph
                color: root.opened ? root.activeColor : SystemIcons.bluetoothColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
                Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            }

            Text {
                anchors.centerIn: parent
                visible: root.bluetoothIcon !== "auto"
                text: root.bluetoothIcon
                color: root.opened ? root.activeColor : SystemIcons.bluetoothColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
                Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            }
        }

        // --- Wi-Fi --------------------------------------------------------
        Item {
            width: Theme.barIconSlot
            height: Theme.barIconSlot
            visible: !root.allSlotsHidden && root.wifiIcon !== ""

            WifiStatusIcon {
                anchors.centerIn: parent
                visible: root.wifiIcon === "auto"
                width: 19
                height: 19
                glyphSize: 14
                offMode: !root.wifiEnabled
                signal: root.wifiSignal
                dim: !root.wifiConnected
            }

            Text {
                anchors.centerIn: parent
                visible: root.wifiIcon !== "auto"
                text: root.wifiIcon
                color: root.wifiEnabled ? (root.wifiConnected ? root.activeColor : Theme.quickTextDim)
                                        : root.dimColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
            }
        }

        // --- Звук ---------------------------------------------------------
        Item {
            width: Theme.barIconSlot
            height: Theme.barIconSlot
            visible: !root.allSlotsHidden && root.soundIcon !== ""

            Text {
                anchors.centerIn: parent
                visible: root.soundIcon === "auto"
                text: SystemIcons.soundGlyph
                color: root.opened ? root.activeColor : SystemIcons.soundColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
                Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            }

            Text {
                anchors.centerIn: parent
                visible: root.soundIcon !== "auto"
                text: root.soundIcon
                color: root.opened ? root.activeColor : SystemIcons.soundColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
                Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
            }
        }

        // Все слоты скрыты — кнопка остаётся входом в быстрые настройки.
        Item {
            width: Theme.barIconSlot
            height: Theme.barIconSlot
            visible: root.allSlotsHidden

            Text {
                anchors.centerIn: parent
                text: "\uf013"
                color: root.activeColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize.sm
            }
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
