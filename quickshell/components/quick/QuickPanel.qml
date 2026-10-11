import QtQuick
import "../../singletons"

// Содержимое попапа: список плиток либо раскрытая панель управления.
// Размеры хоста меняются мгновенно от нужного вида, а окно попапа
// анимированно едет за ними (см. QuickPopup).
Item {
    id: root

    property string panel: ""

    readonly property bool detailOpened: panel !== ""

    readonly property Item activeDetail: panel === "bluetooth" ? bluetoothPanel
                                        : panel === "wifi" ? wifiPanel
                                        : panel === "sound" ? soundPanel
                                        : null

    implicitWidth: detailOpened ? Theme.quickDetailWidth : Theme.quickWidth
    implicitHeight: activeDetail ? activeDetail.implicitHeight : mainColumn.implicitHeight

    Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.quickTileSpacing
        opacity: root.detailOpened ? 0 : 1
        scale: root.detailOpened ? 0.98 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }

        QuickTile {
            icon: "\uf293"
            title: "Bluetooth"
            subtitle: MockState.bluetoothSummary
            active: MockState.bluetoothEnabled
            onToggled: MockState.toggleBluetooth()
            onExpandRequested: root.panel = "bluetooth"
        }

        QuickTile {
            icon: "\uf1eb"
            title: "Wi-Fi"
            subtitle: MockState.wifiSummary
            active: MockState.wifiEnabled
            onToggled: MockState.toggleWifi()
            onExpandRequested: root.panel = "wifi"
        }

        QuickTile {
            icon: MockState.soundEnabled ? "\uf028" : "\uf026"
            title: "Sound"
            subtitle: MockState.soundSummary
            active: MockState.soundEnabled
            onToggled: MockState.toggleSound()
            onExpandRequested: root.panel = "sound"
        }
    }

    PanelBluetooth {
        id: bluetoothPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.panel === "bluetooth" ? 1 : 0
        scale: root.panel === "bluetooth" ? 1 : 0.98
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        onBackRequested: root.panel = ""
    }

    PanelWifi {
        id: wifiPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.panel === "wifi" ? 1 : 0
        scale: root.panel === "wifi" ? 1 : 0.98
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        onBackRequested: root.panel = ""
    }

    PanelSound {
        id: soundPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.panel === "sound" ? 1 : 0
        scale: root.panel === "sound" ? 1 : 0.98
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
            }
        }
        onBackRequested: root.panel = ""
    }
}
