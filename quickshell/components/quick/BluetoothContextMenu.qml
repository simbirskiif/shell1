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
    readonly property real cardHeight: column.implicitHeight + Theme.space.sm
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

    // Карточка меню m3: тональная поверхность surface-container-high,
    // радиус medium, без тени — глубину даёт только тон.
    Rectangle {
        id: card
        x: Math.max(Theme.space.xs, Math.min(UiState.menuDeviceX, root.width - width - Theme.space.sm))
        y: Math.max(Theme.space.xs, Math.min(UiState.menuDeviceY, root.height - height - Theme.space.sm))
        width: 236
        height: root.cardHeight
        radius: Theme.shape.md
        color: Theme.menuSurfaceSolid
        border.width: 1
        border.color: Theme.outlineVariant

        // Клики по карточке не должны её закрывать.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.xs
            spacing: 0

            // Заголовок: имя устройства и, если BlueZ отдаёт Battery1,
            // процент заряда. Без данных о заряде строка не рисуется вовсе.
            Item {
                width: parent.width
                implicitHeight: root.menu && root.menu.batteryKnown
                                ? Theme.space.xxxl + Theme.space.sm : Theme.space.xxxl

                Text {
                    id: deviceName
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.top: parent.top
                    anchors.topMargin: Theme.space.sm
                    elide: Text.ElideRight
                    text: root.menu ? root.menu.name : ""
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyLarge
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.top: deviceName.bottom
                    anchors.topMargin: Theme.space.xs
                    visible: root.menu && root.menu.batteryKnown
                    text: root.menu ? (root.menu.batteryPercent + "%") : ""
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineVariant
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
                opacity: enabled ? 1 : Theme.disabledContent
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
                opacity: enabled ? 1 : Theme.disabledContent
                onTriggered: root.confirming = true
            }

            // Подтверждение удаления: устройство теряет спаривание, и для
            // подключения его придётся спаривать заново.
            Item {
                id: confirmItem
                width: parent.width
                implicitHeight: confirmColumn.implicitHeight + Theme.space.sm
                visible: root.confirming
                height: root.confirming ? implicitHeight : 0

                Column {
                    id: confirmColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.space.xs
                    spacing: Theme.space.xs

                    Text {
                        width: parent.width
                        anchors.margins: Theme.space.md
                        leftPadding: Theme.space.md
                        rightPadding: Theme.space.md
                        wrapMode: Text.WordWrap
                        text: "Удалить устройство и его спаривание?"
                        color: Theme.scheme.onSurface
                        font: Theme.typeBodyMedium
                    }

                    // Кнопки выравниваются по правому краю и не могут выйти
                    // за карточку: ширина каждой ограничена половиной строки.
                    Item {
                        width: parent.width
                        height: Theme.buttonHeight

                        MenuButton {
                            id: cancelButton
                            anchors.right: deleteButton.left
                            anchors.rightMargin: Theme.space.sm
                            maxWidth: (parent.width - Theme.space.sm) / 2
                            text: "Отмена"
                            onTriggered: root.confirming = false
                        }

                        MenuButton {
                            id: deleteButton
                            anchors.right: parent.right
                            maxWidth: (parent.width - Theme.space.sm) / 2
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

    // Строка меню m3: иконка, подпись, подсветка опасного действия.
    // Высота пункта — 48, hover — state layer поверх скруглённой подложки.
    component MenuRow: Item {
        id: row

        property string icon: ""
        property string text: ""
        property bool danger: false

        signal triggered()

        implicitWidth: column.width
        implicitHeight: Theme.touchTarget

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.space.xs
            radius: Theme.shape.xs
            color: rowHover.containsMouse && row.enabled
                   ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                   : "transparent"
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
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            text: row.icon
            color: row.danger ? Theme.error : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
        }

        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: Theme.space.md
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.text
            color: row.danger ? Theme.error : Theme.scheme.onSurface
            font: Theme.typeLabelLarge
        }
    }

    // Кнопка m3: текстовая (прозрачная, подпись primary) или залитая
    // (primary, опасное действие — error).
    component MenuButton: Rectangle {
        id: button

        property string text: ""
        property bool primary: false
        property bool danger: false
        // Предел ширины: кнопка не должна выходить за карточку.
        property real maxWidth: 1000

        signal triggered()

        readonly property color accentColor: button.danger ? Theme.error : Theme.primary
        readonly property color accentLabel: button.danger ? Theme.scheme.onError
                                                           : Theme.scheme.onPrimary

        width: Math.min(buttonLabel.implicitWidth + Theme.space.lg, maxWidth)
        height: Theme.buttonHeight
        radius: Theme.shape.full
        // Второстепенное действие — текстовая кнопка m3: без заливки и обводки,
        // только подпись primary и слой состояния.
        color: button.primary ? button.accentColor : "transparent"

        // Слой состояния m3: на залитой кнопке — по on-primary/on-error,
        // на текстовой — по primary/error.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: button.primary
                   ? Theme.stateLayer(button.accentLabel, Theme.stateHover)
                   : Theme.stateLayer(button.accentColor, Theme.stateHover)
            opacity: buttonHover.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, button.width - Theme.space.md)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: button.text
            color: button.primary ? button.accentLabel : button.accentColor
            font: Theme.typeLabelLarge
        }

        MouseArea {
            id: buttonHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
