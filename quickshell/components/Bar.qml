import QtQuick
import Quickshell
import Quickshell.Wayland
import "quick"
import "expressive"
import "../singletons"

// Верхний бар: слева рабочие столы, по центру время, справа — батарея,
// уведомления и кнопка статуса. В Expressive бар — не полоса на всю
// ширину, а плавающая пилюля с воздухом по краям.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: "transparent"
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

    // Плавающая карточка бара: скруглённая пилюля, лёгкий тональный
    // градиент к tertiary — цветовая иерархия вместо серой полосы.
    Rectangle {
        id: barCard
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: height / 2
        color: Theme.barSurface
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.barSurface }
            GradientStop { position: 0.55; color: Theme.barSurface }
            GradientStop { position: 1.0; color: Theme.withAlpha(Theme.tertiaryContainer, 0.55) }
        }
    }

    Workspaces {
        anchors.left: barCard.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: barCard.verticalCenter
        screenName: root.screen ? root.screen.name : ""
    }

    Clock {
        anchors.horizontalCenter: barCard.horizontalCenter
        anchors.verticalCenter: barCard.verticalCenter
    }

    // Порядок элементов задаётся в настройках (MockState.barItems).
    Row {
        anchors.right: barCard.right
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: barCard.verticalCenter
        spacing: Theme.space.xs

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
            opened: NotificationService.centerOpen
            onClicked: NotificationService.toggleCenter()
        }
    }

    Component {
        id: batteryItem

        BatteryButton {
            showPercent: MockState.showBatteryPercent
            level: PowerService.level
            charging: PowerService.charging
            onClicked: UiState.open(root.screen ? root.screen.name : "", "battery")
        }
    }

    Component {
        id: statusItem

        ControlButton {
            bluetoothEnabled: BluetoothBackend.enabled
            wifiEnabled: NetworkService.wifiEnabled
            wifiConnected: NetworkService.wifiConnected
            wifiSignal: NetworkService.connectedSignal
            soundEnabled: !AudioService.outputMuted
            opened: quickPopup.visible
            onClicked: quickPopup.toggle()
        }
    }
}
