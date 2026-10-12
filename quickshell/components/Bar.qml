import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "../singletons"

// Верхний бар: слева рабочие столы, по центру дата и время,
// справа — элементы из настроек (батарея, кнопка статуса и будущие).
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: Theme.barBackground
    exclusiveZone: Theme.barHeight
    WlrLayershell.namespace: "quickshell-bar"

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screenName: root.screen ? root.screen.name : ""
    }

    Clock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    // Порядок элементов задаётся в настройках (MockState.barItems).
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: MockState.barItems

            delegate: Loader {
                required property string itemKey

                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: itemKey === "battery" ? batteryItem
                               : itemKey === "status" ? statusItem
                               : null
            }
        }
    }

    QuickPopup {
        id: quickPopup
        anchorWindow: root
    }

    // Запрос пароля — отдельным модальным окном (у попапа нет клавиатуры).
    PasswordDialog {
        dialogScreen: root.screen
    }

    Component {
        id: batteryItem

        BatteryButton {
            showPercent: MockState.showBatteryPercent
            level: MockState.batteryLevel
            charging: MockState.batteryCharging
            onClicked: UiState.open(root.screen ? root.screen.name : "", "battery")
        }
    }

    Component {
        id: statusItem

        ControlButton {
            bluetoothEnabled: MockState.bluetoothEnabled
            wifiEnabled: MockState.wifiEnabled
            soundEnabled: MockState.soundEnabled
            opened: quickPopup.visible
            onClicked: quickPopup.toggle()
        }
    }
}
