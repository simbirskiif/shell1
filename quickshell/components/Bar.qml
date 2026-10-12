import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "../singletons"

// Верхний бар: слева рабочие столы, по центру дата и время,
// справа — кнопка статуса bt/wifi/sound с попапом быстрых настроек.
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

    // Батарея в баре (включается в настройках).
    BatteryButton {
        anchors.right: controlButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        visible: MockState.showBatteryPercent
        level: MockState.batteryLevel
        charging: MockState.batteryCharging
        onClicked: UiState.open(root.screen ? root.screen.name : "", "battery")
    }

    ControlButton {
        id: controlButton
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        bluetoothEnabled: MockState.bluetoothEnabled
        wifiEnabled: MockState.wifiEnabled
        soundEnabled: MockState.soundEnabled
        opened: quickPopup.visible
        onClicked: quickPopup.toggle()
    }

    QuickPopup {
        id: quickPopup
        anchorWindow: root
    }
}
