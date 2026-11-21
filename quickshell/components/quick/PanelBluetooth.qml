import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Панель Bluetooth: поиск, сохранённые (спаренные) устройства и найденные.
// Когда Bluetooth выключен — единый экран-заглушка. Когда адаптера нет или
// он заблокирован rfkill — отдельная заглушка без кнопки включения.
//
// Вся логика — в BluetoothBackend: здесь только привязки к его свойствам,
// моделям и методам.
//
// Expressive: устройства — крупные строки-пилюли (подключённое — tertiary-
// контейнер), секции сгруппированы формой и цветом, разделителей нет.
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
            // Expressive: крупная пилюля secondary-контейнера с орбом.
            Item {
                width: parent.width
                height: BluetoothBackend.discoverable ? 56 : 0
                visible: height > 0
                clip: true

                MorphShape {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.xs
                    anchors.rightMargin: Theme.space.xs
                    anchors.topMargin: Theme.space.xs
                    anchors.bottomMargin: Theme.space.xs
                    shape: "pill"
                    color: Theme.secondaryContainer
                    modulation: 0.35
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.sm

                    MorphShape {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        shape: "sunny"
                        color: Theme.primaryContainer
                        modulation: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf06e"
                            color: Theme.scheme.onPrimaryContainer
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize.sm
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Discoverable — visible to nearby devices"
                        color: Theme.scheme.onSecondaryContainer
                        font: Theme.typeLabelLarge
                    }
                }
            }

            // Заголовок секции Expressive: крупнее и жирнее обычной подписи.
            Item {
                width: parent.width
                height: 40
                visible: BluetoothBackend.pairedDevices.count > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.xs
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space.xs
                    text: "My devices"
                    color: Theme.primary
                    font: Theme.typeEmphasizedTitleMedium
                }
            }

            PanelList {
                width: parent.width
                visible: BluetoothBackend.pairedDevices.count > 0
                height: visible ? implicitHeight : 0
                rowHeight: 62
                model: BluetoothBackend.pairedDevices

                delegate: BluetoothRow {
                    // Поля модели приходят из BluetoothBackend.toItem().
                    onActivated: BluetoothBackend.toggleConnection(address)
                    onContextRequested: (x, y) => UiState.openDeviceMenu(address, x, y)
                }
            }

            // Пусто в «Сохранённых» — подсказываем, как добавить устройство.
            // Expressive: не строка текста, а форма-клякса с подписью.
            Item {
                width: parent.width
                height: BluetoothBackend.pairedDevices.count === 0 ? 64 : 0
                visible: height > 0

                MorphShape {
                    id: emptyBlob
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    shape: "blob"
                    color: Theme.withAlpha(Theme.primary, 0.16)
                    modulation: 1
                }

                Text {
                    anchors.left: emptyBlob.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: "No saved devices yet"
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }
            }

            Item {
                width: parent.width
                height: 40
                // Заголовок показываем, если есть что показать в секции:
                // либо именованные, либо свёрнутые безымянные устройства.
                visible: BluetoothBackend.newDevices.count > 0
                         || BluetoothBackend.unnamedDevices.count > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.xs
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space.xs
                    text: "Available"
                    color: Theme.primary
                    font: Theme.typeEmphasizedTitleMedium
                }
            }

            PanelList {
                width: parent.width
                rowHeight: 62
                model: BluetoothBackend.newDevices

                delegate: BluetoothRow {
                    onActivated: BluetoothBackend.toggleConnection(address)
                    onContextRequested: (x, y) => UiState.openDeviceMenu(address, x, y)
                }
            }

            // Устройства без имени (только MAC) не забивают список: они
            // свёрнуты под этой строкой. Expressive: пилюля-раскрывашка.
            Item {
                id: unnamedToggle
                width: parent.width
                height: BluetoothBackend.unnamedDevices.count > 0 ? 52 : 0
                visible: height > 0

                readonly property bool expanded: UiState.btShowUnnamed
                readonly property bool hovered: toggleHover.containsMouse

                MorphShape {
                    anchors.fill: parent
                    anchors.margins: Theme.space.xs
                    shape: unnamedToggle.hovered ? "squircle" : "pill"
                    color: unnamedToggle.hovered ? Theme.surfaceContainerHighest
                                                 : Theme.surfaceContainerHigh
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: toggleIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    text: unnamedToggle.expanded ? "\uf077" : "\uf078"
                    color: Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: toggleIcon.right
                    anchors.leftMargin: Theme.space.sm
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: (unnamedToggle.expanded ? "Скрыть безымянные" : "Показать ещё")
                          + " (" + BluetoothBackend.unnamedDevices.count + ")"
                    color: Theme.scheme.onSurface
                    font: Theme.typeEmphasizedLabelLarge
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
                rowHeight: 62
                model: BluetoothBackend.unnamedDevices

                delegate: BluetoothRow {
                    onActivated: BluetoothBackend.toggleConnection(address)
                    onContextRequested: (x, y) => UiState.openDeviceMenu(address, x, y)
                }
            }

        }
    }
}
