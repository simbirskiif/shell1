import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "player"
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

    // Кофеин: idle-inhibit привязывается к поверхности, поэтому ингибитор
    // живёт в окне бара — у каждого экрана своя поверхность, но включён он
    // только когда выбран режим.
    IdleInhibitor {
        enabled: CaffeineService.active
        window: root
    }

    // Правка строковых настроек (сейчас — длительности кофеина): попап не
    // может забрать клавиатуру, поэтому ввод идёт в отдельном окне.
    InputDialog {
        dialogScreen: root.screen
    }

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

                // Батареи нет (десктоп) — индикатор не показываем совсем:
                // Positioner пропускает невидимый элемент вместе с отступом.
                visible: itemKey !== "battery" || PowerService.present
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: itemKey === "battery" ? batteryItem
                               : itemKey === "notifications" ? notificationsItem
                               : itemKey === "status" ? statusItem
                               : itemKey === "wifi" ? wifiItem
                               : itemKey === "bluetooth" ? bluetoothItem
                               : itemKey === "brightness" ? brightnessItem
                               : itemKey === "sound" ? soundItem
                               : itemKey === "player" ? playerItem
                               : null
            }
        }
    }

    QuickPopup {
        id: quickPopup
        anchorWindow: root
    }

    // Жест двумя пальцами по бару тоже возвращает назад, если открыта
    // дочерняя панель. acceptedButtons: NoButton — клики пропускаем.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: 10

        onWheel: wheel => {
            const dx = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x;
            const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;
            if (!UiState.swipeActive && Math.abs(dx) <= Math.abs(dy))
                return;
            if (dx === 0)
                return;
            wheel.accepted = true;
            UiState.swipeBy(dx, Theme.quickWidth);
        }
    }

    // Запрос пароля — отдельным модальным окном (у попапа нет клавиатуры).
    PasswordDialog {
        dialogScreen: root.screen
    }

    // Запрос BlueZ-агента (PIN/passkey/подтверждение): отдельная поверхность,
    // потому что попап не может забрать клавиатурный фокус.
    BluetoothPinDialog {
        dialogScreen: root.screen
    }


    Component {
        id: notificationsItem

        NotificationButton {
            iconGlyph: MockState.iconFor("notifications")
            opened: NotificationService.centerOpen
            onClicked: NotificationService.toggleCenter()
        }
    }

    Component {
        id: batteryItem

        BatteryButton {
            iconOverride: MockState.iconFor("battery")
            showPercent: MockState.showBatteryPercent
            level: PowerService.level
            charging: PowerService.charging
            onClicked: UiState.open(root.screen ? root.screen.name : "", "battery")
        }
    }

    Component {
        id: statusItem

        ControlButton {
            bluetoothIcon: MockState.statusIconFor("bluetooth")
            wifiIcon: MockState.statusIconFor("wifi")
            soundIcon: MockState.statusIconFor("sound")
            bluetoothEnabled: BluetoothBackend.enabled
            wifiEnabled: NetworkService.wifiEnabled
            wifiConnected: NetworkService.wifiConnected
            wifiSignal: NetworkService.connectedSignal
            soundEnabled: !AudioService.outputMuted
            opened: quickPopup.visible
            onClicked: quickPopup.toggle()
        }
    }

    // Быстрые действия открывают свои панели — как батарея и уведомления.
    // Тумблеры радио остаются внутри панелей, чтобы случайный клик по бару
    // не отключал сеть.
    Component {
        id: wifiItem

        BarActionButton {
            kind: "wifi"
            iconOverride: MockState.iconFor("wifi")
            wifiEnabled: NetworkService.wifiEnabled
            wifiConnected: NetworkService.wifiConnected
            wifiSignal: NetworkService.connectedSignal
            onClicked: UiState.open(root.screen ? root.screen.name : "", "internet")
        }
    }

    Component {
        id: bluetoothItem

        BarActionButton {
            kind: "bluetooth"
            iconOverride: MockState.iconFor("bluetooth")
            bluetoothEnabled: BluetoothBackend.enabled
            onClicked: UiState.open(root.screen ? root.screen.name : "", "bluetooth")
        }
    }

    Component {
        id: brightnessItem

        BarActionButton {
            kind: "brightness"
            iconOverride: MockState.iconFor("brightness")
            onClicked: UiState.open(root.screen ? root.screen.name : "", "brightness")
        }
    }

    Component {
        id: soundItem

        BarActionButton {
            kind: "sound"
            iconOverride: MockState.iconFor("sound")
            onClicked: UiState.open(root.screen ? root.screen.name : "", "sound")
        }
    }

    Component {
        id: playerItem

        PlayerBarButton {
            iconOverride: MockState.iconFor("player")
            onClicked: PlayerWindowState.toggle(root.screen ? root.screen.name : "")
        }
    }
}
