import QtQuick
import Quickshell
import ".."
import "../../singletons"

// Контекстное меню Bluetooth-устройства (правый клик по строке в списке):
// «Подключиться / Отключиться» и «Удалить устройство».
//
// Данные для меню целиком приходят из BluetoothBackend (currentMenu): имя,
// заряд, подпись пункта подключения и признаки доступности. Здесь нет ни
// одного обращения к BlueZ напрямую — меню только рисует и зовёт методы
// бэкенда.
//
// Меню живёт внутри того же окна, что и панель быстрых настроек (как и меню
// Wi-Fi-сети): это позволяет рисовать его поверх любых layer-shell
// поверхностей, а координаты клика остаются локальными для окна панели.
Item {
    id: root

    // Клик мимо карточки закрывает меню.
    anchors.fill: parent

    // Данные выбранного устройства. null, если меню закрыто.
    readonly property var menu: BluetoothBackend.currentMenu
    property bool confirming: false
    readonly property bool open: UiState.menuDeviceAddress !== "" && menu !== null

    // Высота карточки. Считаем по колонке целиком: она сама учитывает
    // состояние — скрытые пункты имеют height 0, а блок подтверждения свою
    // высоту. Прежний вариант брал при подтверждении только confirmItem и
    // ЗАБЫВАЛ заголовок с именем и зарядом, который остаётся видимым: карточка
    // выходила на ~50 px ниже, и кнопки «Отмена»/«Удалить» оказывались за её
    // пределами.
    readonly property real cardHeight: column.implicitHeight + 8
    // Высота, которую резервирует окно попапа. Совпадает с текущей высотой
    // карточки: пока меню открыто, окно меняет размер без анимации, поэтому
    // карточка не обрезается.
    readonly property real maxCardHeight: cardHeight

    visible: open

    // Меню закрылось — снимаем подтверждение и отпускаем устройство в бэкенде.
    onVisibleChanged: {
        if (!visible) {
            confirming = false;
            BluetoothBackend.closeMenu();
        }
    }

    function close() {
        confirming = false;
        UiState.closeDeviceMenu();
    }

    // Устройство могло исчезнуть (например, его удалили в другом месте) —
    // закрываем меню, чтобы не показывать пустую карточку.
    Connections {
        target: UiState

        function onMenuDeviceAddressChanged() {
            if (UiState.menuDeviceAddress === "")
                return;
            BluetoothBackend.openMenu(UiState.menuDeviceAddress);
            if (BluetoothBackend.currentMenu === null)
                root.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.close()
    }

    Rectangle {
        id: card
        x: Math.max(4, Math.min(UiState.menuDeviceX, root.width - width - 8))
        y: Math.max(4, Math.min(UiState.menuDeviceY, root.height - height - 8))
        width: 236
        height: root.cardHeight
        radius: 14
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        // Клики по карточке не должны её закрывать.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 0

            // Заголовок: имя устройства и, если BlueZ отдаёт Battery1,
            // процент заряда. Без данных о заряде строка не рисуется вовсе.
            Item {
                width: parent.width
                implicitHeight: root.menu && root.menu.batteryKnown ? 46 : 34

                Text {
                    id: deviceName
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    elide: Text.ElideRight
                    text: root.menu ? root.menu.name : ""
                    color: Theme.quickText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.top: deviceName.bottom
                    anchors.topMargin: 2
                    visible: root.menu && root.menu.batteryKnown
                    text: root.menu ? (root.menu.batteryPercent + "%") : ""
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.quickSeparator
            }

            MenuRow {
                visible: !root.confirming
                height: root.confirming ? 0 : implicitHeight
                // Во время спаривания пункт прерывает операцию, поэтому и
                // значок другой (крестик), и подпись «Отменить сопряжение».
                icon: root.menu && root.menu.cancellable
                      ? "\uf00d"
                      : (root.menu && root.menu.connected ? "\uf011" : "\uf1e6")
                text: root.menu ? root.menu.actionLabel : ""
                enabled: root.menu !== null && root.menu.canToggle
                opacity: enabled ? 1 : 0.4
                onTriggered: {
                    if (root.menu && root.menu.cancellable)
                        BluetoothBackend.cancelConnection();
                    else
                        BluetoothBackend.toggleConnection(UiState.menuDeviceAddress);
                    root.close();
                }
            }

            MenuRow {
                visible: !root.confirming
                height: root.confirming ? 0 : implicitHeight
                icon: "\uf1f8"
                text: "Удалить устройство"
                danger: true
                enabled: root.menu !== null && root.menu.canForget
                opacity: enabled ? 1 : 0.4
                onTriggered: root.confirming = true
            }

            // Подтверждение удаления: устройство теряет спаривание, и для
            // подключения его придётся спаривать заново.
            Item {
                id: confirmItem
                width: parent.width
                implicitHeight: confirmColumn.implicitHeight + 8
                visible: root.confirming
                height: root.confirming ? implicitHeight : 0

                Column {
                    id: confirmColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    spacing: 2

                    Text {
                        width: parent.width
                        anchors.margins: 14
                        leftPadding: 14
                        rightPadding: 14
                        wrapMode: Text.WordWrap
                        text: "Удалить устройство и его спаривание?"
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    // Кнопки выравниваются по правому краю и не могут выйти
                    // за карточку: ширина каждой ограничена половиной строки.
                    Item {
                        width: parent.width
                        height: 30

                        MenuButton {
                            id: cancelButton
                            anchors.right: deleteButton.left
                            anchors.rightMargin: 6
                            maxWidth: (parent.width - 6) / 2
                            text: "Отмена"
                            onTriggered: root.confirming = false
                        }

                        MenuButton {
                            id: deleteButton
                            anchors.right: parent.right
                            maxWidth: (parent.width - 6) / 2
                            text: "Удалить"
                            primary: true
                            danger: true
                            onTriggered: {
                                BluetoothBackend.forgetDevice(UiState.menuDeviceAddress);
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

    // Строка меню: иконка, подпись, подсветка опасного действия.
    component MenuRow: Item {
        id: row

        property string icon: ""
        property string text: ""
        property bool danger: false

        signal triggered()

        implicitWidth: column.width
        implicitHeight: 40

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: rowHover.hovered && row.enabled ? Theme.quickTileHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: row.triggered()
        }

        Text {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: row.icon
            color: row.danger ? Theme.lowColor : Theme.quickTextDim
            font.family: Theme.iconFontFamily
            font.pixelSize: 13
        }

        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.text
            color: row.danger ? Theme.lowColor : Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    // Кнопка подтверждения.
    component MenuButton: Rectangle {
        id: button

        property string text: ""
        property bool primary: false
        property bool danger: false
        // Предел ширины: кнопка не должна выходить за карточку.
        property real maxWidth: 1000

        signal triggered()

        width: Math.min(buttonLabel.implicitWidth + 24, maxWidth)
        height: 30
        radius: 15
        color: primary ? (danger ? Theme.lowColor : Theme.accent) : "transparent"
        border.width: primary ? 0 : 1
        border.color: Theme.quickBorder

        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, button.width - 20)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: button.text
            color: primary ? Theme.quickIconOn : Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
