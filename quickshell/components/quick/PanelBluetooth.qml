import QtQuick
import ".."
import "../../singletons"

// Панель Bluetooth: поиск, сохранённые (спаренные) устройства и найденные.
// Когда Bluetooth выключен — единый экран-заглушка. Когда адаптера нет или
// он заблокирован rfkill — отдельная заглушка без кнопки включения.
//
// Вся логика — в BluetoothBackend: здесь только привязки к его свойствам,
// моделям и методам.
Item {
    id: root

    signal backRequested()

    implicitWidth: Theme.quickWidth
    implicitHeight: column.implicitHeight

    // Открыли панель — запускаем поиск устройств. Скан идёт, пока панель
    // открыта, и останавливается при уходе из неё (см. onPanelChanged).
    property bool wasOpen: false

    // Плашка ошибки подключения/удаления. Показывается по lastError и
    // гаснет сама, чтобы не висеть поверх списка.
    property bool warningVisible: false

    Connections {
        target: UiState

        function onPanelChanged() {
            const open = UiState.panel === "bluetooth";
            if (open && !root.wasOpen) {
                BluetoothBackend.clearError();
                root.warningVisible = false;
                BluetoothBackend.startScan();
            } else if (!open && root.wasOpen) {
                BluetoothBackend.stopScan();
            }
            root.wasOpen = open;
        }
    }

    // Ошибка от бэкенда: показываем плашку и заводим таймер автоскрытия.
    Connections {
        target: BluetoothBackend

        function onConnectionFailed(address, reason) {
            root.warningVisible = true;
            warningTimer.restart();
        }

        function onForgetFailed(address, reason) {
            root.warningVisible = true;
            warningTimer.restart();
        }

        // Адаптер включился, пока панель открыта: запускаем отложенный поиск.
        // Сразу после включения Bluetooth ещё не может сканировать, поэтому
        // старт скана привязан к факту включения, а не к нажатию тумблера.
        function onEnabledChanged() {
            const open = UiState.panel === "bluetooth";
            if (open && BluetoothBackend.enabled)
                BluetoothBackend.startScan();
        }
    }

    Timer {
        id: warningTimer
        // Дольше, чем раньше: в плашке теперь подсказка и кнопка «Повторить»,
        // их нужно успеть прочитать.
        interval: 12000
        onTriggered: {
            root.warningVisible = false;
            BluetoothBackend.clearError();
        }
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        PanelHeader {
            title: "Bluetooth"
            // Тумблер показывает фактическое состояние адаптера.
            checked: BluetoothBackend.enabled
            // Кнопка включения бессмысленна без адаптера и при rfkill.
            switchable: BluetoothBackend.available
            refreshable: true
            refreshing: BluetoothBackend.scanning
            actionIcon: "\uf06e"
            actionChecked: BluetoothBackend.discoverable
            onBackRequested: root.backRequested()
            onToggled: {
                BluetoothBackend.toggleEnabled();
                // Включаем — сразу начинаем поиск; выключаем — скан снят
                // самим бэкендом.
                if (BluetoothBackend.enabled)
                    BluetoothBackend.startScan();
            }
            onRefreshRequested: {
                if (BluetoothBackend.scanning)
                    BluetoothBackend.stopScan();
                else
                    BluetoothBackend.startScan();
            }
            onActionRequested: BluetoothBackend.toggleDiscoverable()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
        }

        // Ошибка подключения/удаления: причина, подсказка что делать и
        // кнопка повтора. Гаснет сама, чтобы не висеть поверх списка.
        PanelWarning {
            id: errorBanner
            width: parent.width
            visible: root.warningVisible
            height: visible ? implicitHeight : 0
            title: BluetoothBackend.lastError
            description: BluetoothBackend.lastErrorHint
            actionText: BluetoothBackend.lastFailedAddress !== "" ? "Повторить" : ""
            icon: "\uf071"
            onActionRequested: {
                const address = BluetoothBackend.lastFailedAddress;
                if (address !== "") {
                    BluetoothBackend.toggleConnection(address);
                    root.warningVisible = false;
                    warningTimer.stop();
                }
            }
        }

        // Bluetooth выключен — единый экран-заглушка.
        PanelDisabled {
            width: parent.width
            visible: !BluetoothBackend.enabled && BluetoothBackend.available
            height: visible ? implicitHeight : 0
            icon: "\uf293"
            title: "Bluetooth is off"
            description: "Turn Bluetooth on to find nearby devices"
            actionText: "Turn on"
            onActionRequested: {
                BluetoothBackend.setEnabled(true);
                BluetoothBackend.startScan();
            }
        }

        // Адаптера нет (нет железа, BlueZ не запущен, включён rfkill):
        // включить Bluetooth из оболочки нельзя, кнопки быть не должно.
        PanelDisabled {
            width: parent.width
            visible: !BluetoothBackend.available
            height: visible ? implicitHeight : 0
            icon: "\uf293"
            title: BluetoothBackend.blocked ? "Bluetooth is blocked" : "No Bluetooth adapter"
            description: BluetoothBackend.blocked
                    ? "Bluetooth is blocked by rfkill. Unblock it to continue."
                    : "No Bluetooth adapter was found on this system."
            actionText: ""
            showAction: false
        }

        Column {
            id: enabledContent
            width: parent.width
            visible: BluetoothBackend.enabled
            height: visible ? implicitHeight : 0
            spacing: 0

            // Режим обнаружения: пока включён, устройство видно другим.
            Item {
                width: parent.width
                height: BluetoothBackend.discoverable ? 44 : 0
                visible: height > 0
                clip: true

                // Постоянное состояние — иконка, а не крутящийся индикатор.
                Text {
                    id: discoverIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf06e"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 14
                }

                Text {
                    anchors.left: discoverIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Discoverable — visible to nearby devices"
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            PanelSection {
                text: "My devices"
                visible: BluetoothBackend.pairedDevices.count > 0
                height: visible ? implicitHeight : 0
            }

            PanelList {
                width: parent.width
                visible: BluetoothBackend.pairedDevices.count > 0
                height: visible ? implicitHeight : 0
                model: BluetoothBackend.pairedDevices

                delegate: BluetoothRow {
                    // Поля модели приходят из BluetoothBackend.toItem().
                    onActivated: BluetoothBackend.toggleConnection(address)
                    onContextRequested: (x, y) => UiState.openDeviceMenu(address, x, y)
                }
            }

            // Пусто в «Сохранённых» — подсказываем, как добавить устройство.
            Item {
                width: parent.width
                height: BluetoothBackend.pairedDevices.count === 0 ? 40 : 0
                visible: height > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No saved devices yet"
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            PanelSection {
                text: "Available"
                // Заголовок показываем, если есть что показать в секции:
                // либо именованные, либо свёрнутые безымянные устройства.
                visible: BluetoothBackend.newDevices.count > 0
                         || BluetoothBackend.unnamedDevices.count > 0
                height: visible ? implicitHeight : 0
            }

            PanelList {
                width: parent.width
                model: BluetoothBackend.newDevices

                delegate: BluetoothRow {
                    onActivated: BluetoothBackend.toggleConnection(address)
                    onContextRequested: (x, y) => UiState.openDeviceMenu(address, x, y)
                }
            }

            // Устройства без имени (только MAC) не забивают список: они
            // свёрнуты под этой строкой.
            Item {
                id: unnamedToggle
                width: parent.width
                height: BluetoothBackend.unnamedDevices.count > 0 ? 36 : 0
                visible: height > 0

                readonly property bool expanded: UiState.btShowUnnamed

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 10
                    color: toggleHover.hovered ? Theme.quickTileHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
                }

                Text {
                    id: toggleIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: unnamedToggle.expanded ? "\uf077" : "\uf078"
                    color: Theme.quickTextDim
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 12
                }

                Text {
                    anchors.left: toggleIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: (unnamedToggle.expanded ? "Скрыть безымянные" : "Показать ещё")
                          + " (" + BluetoothBackend.unnamedDevices.count + ")"
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    id: toggleHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.btShowUnnamed = !UiState.btShowUnnamed
                }
            }

            PanelList {
                width: parent.width
                visible: UiState.btShowUnnamed
                height: visible ? implicitHeight : 0
                model: BluetoothBackend.unnamedDevices

                delegate: BluetoothRow {
                    onActivated: BluetoothBackend.toggleConnection(address)
                    onContextRequested: (x, y) => UiState.openDeviceMenu(address, x, y)
                }
            }

        }
    }
}
