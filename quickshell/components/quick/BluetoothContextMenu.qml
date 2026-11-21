import QtQuick
import Quickshell
import ".."
import "../expressive"
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
//
// Expressive: плавающая карточка радиуса 32, пункты — крупные пилюли,
// hover — secondary-контейнер (удаление — error-контейнер). Разделителей нет.
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
    readonly property real cardHeight: column.implicitHeight + Theme.space.lg
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

    // Плавающая карточка меню: радиус 32, тональная поверхность, без рамки.
    Rectangle {
        id: card
        x: Math.max(Theme.space.sm, Math.min(UiState.menuDeviceX, root.width - width - Theme.space.sm))
        y: Math.max(Theme.space.sm, Math.min(UiState.menuDeviceY, root.height - height - Theme.space.sm))
        width: 250
        height: root.cardHeight
        radius: Theme.shape.xlIncreased
        color: Theme.menuSurfaceSolid

        // Клики по карточке не должны её закрывать.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.sm
            spacing: 2

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
                    font: Theme.typeEmphasizedTitleMedium
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.top: deviceName.bottom
                    anchors.topMargin: 0
                    visible: root.menu && root.menu.batteryKnown
                    text: root.menu ? (root.menu.batteryPercent + "%") : ""
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodySmall
                }
            }

            // Подключиться / отключиться / отменить сопряжение.
            Item {
                id: toggleRow
                width: parent.width
                visible: !root.confirming
                height: visible ? 52 : 0

                readonly property bool hovered: toggleHover.containsMouse
                readonly property bool pressed: toggleHover.pressed

                enabled: root.menu !== null && root.menu.canToggle
                scale: pressed ? 0.98 : 1
                opacity: enabled ? 1 : Theme.disabledContent
                Behavior on scale { SpringSpatialFast {} }
                Behavior on opacity { SpringEffects {} }

                MorphShape {
                    anchors.fill: parent
                    shape: toggleRow.hovered ? "squircle" : "pill"
                    color: toggleRow.hovered ? Theme.secondaryContainer : "transparent"
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: toggleIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    // Во время спаривания пункт прерывает операцию, поэтому и
                    // значок другой (крестик), и подпись «Отменить сопряжение».
                    text: root.menu && root.menu.cancellable
                          ? "\uf00d"
                          : (root.menu && root.menu.connected ? "\uf011" : "\uf1e6")
                    color: toggleRow.hovered ? Theme.scheme.onSecondaryContainer
                                             : Theme.scheme.onSurfaceVariant
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: toggleIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.menu ? root.menu.actionLabel : ""
                    color: toggleRow.hovered ? Theme.scheme.onSecondaryContainer
                                             : Theme.scheme.onSurface
                    font: Theme.typeEmphasizedLabelLarge
                }

                MouseArea {
                    id: toggleHover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: toggleRow.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.menu && root.menu.cancellable)
                            BluetoothBackend.cancelConnection();
                        else
                            BluetoothBackend.toggleConnection(UiState.menuDeviceAddress);
                        root.close();
                    }
                }
            }

            // «Удалить устройство» — опасное действие в error-цвете.
            Item {
                id: forgetRow
                width: parent.width
                visible: !root.confirming
                height: visible ? 52 : 0

                readonly property bool hovered: forgetHover.containsMouse
                readonly property bool pressed: forgetHover.pressed

                enabled: root.menu !== null && root.menu.canForget
                scale: pressed ? 0.98 : 1
                opacity: enabled ? 1 : Theme.disabledContent
                Behavior on scale { SpringSpatialFast {} }
                Behavior on opacity { SpringEffects {} }

                MorphShape {
                    anchors.fill: parent
                    shape: forgetRow.hovered ? "squircle" : "pill"
                    color: forgetRow.hovered ? Theme.errorContainer : "transparent"
                    modulation: 0.35

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: forgetIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf1f8"
                    color: Theme.error
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize.md
                }

                Text {
                    anchors.left: forgetIcon.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: "Удалить устройство"
                    color: Theme.error
                    font: Theme.typeEmphasizedLabelLarge
                }

                MouseArea {
                    id: forgetHover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: forgetRow.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.confirming = true
                }
            }

            // Подтверждение удаления: устройство теряет спаривание, и для
            // подключения его придётся спаривать заново.
            Item {
                id: confirmItem
                width: parent.width
                visible: root.confirming
                implicitHeight: confirmColumn.implicitHeight + Theme.space.sm

                Column {
                    id: confirmColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.space.xs
                    spacing: Theme.space.xs

                    Text {
                        width: parent.width
                        leftPadding: Theme.space.sm
                        rightPadding: Theme.space.sm
                        wrapMode: Text.WordWrap
                        text: "Удалить устройство и его спаривание?"
                        color: Theme.scheme.onSurface
                        font: Theme.typeBodyMedium
                    }

                    // Кнопки выравниваются по правому краю и не могут выйти
                    // за карточку: ширина каждой ограничена половиной строки.
                    Item {
                        width: parent.width
                        height: 44

                        // «Отмена» — тональная пилюля.
                        Item {
                            id: cancelButton
                            anchors.right: deleteButton.left
                            anchors.rightMargin: Theme.space.sm
                            width: Math.min(cancelLabel.implicitWidth + Theme.space.lg,
                                            (parent.width - Theme.space.sm) / 2)
                            height: 44
                            scale: cancelHover.pressed ? 0.94 : (cancelHover.containsMouse ? 1.04 : 1)

                            Behavior on scale { SpringSpatialFast {} }

                            MorphShape {
                                anchors.fill: parent
                                shape: cancelHover.containsMouse ? "squircle" : "pill"
                                color: Theme.surfaceContainerHigh
                                modulation: 0.4
                            }

                            Text {
                                id: cancelLabel
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - Theme.space.sm)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                text: "Отмена"
                                color: Theme.scheme.onSurface
                                font: Theme.typeEmphasizedLabelLarge
                            }

                            MouseArea {
                                id: cancelHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirming = false
                            }
                        }

                        // «Удалить» — залитая error-пилюля.
                        Item {
                            id: deleteButton
                            readonly property bool hovered: deleteHover.containsMouse
                            anchors.right: parent.right
                            width: Math.min(deleteLabel.implicitWidth + Theme.space.lg,
                                            (parent.width - Theme.space.sm) / 2)
                            height: 44
                            scale: deleteHover.pressed ? 0.94 : (hovered ? 1.04 : 1)

                            Behavior on scale { SpringSpatialFast {} }

                            MorphShape {
                                anchors.fill: parent
                                shape: deleteButton.hovered ? "squircle" : "pill"
                                color: Theme.error
                                modulation: 0.4
                            }

                            Text {
                                id: deleteLabel
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - Theme.space.sm)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                text: "Удалить"
                                color: Theme.scheme.onError
                                font: Theme.typeEmphasizedLabelLarge
                            }

                            MouseArea {
                                id: deleteHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    BluetoothBackend.forgetDevice(UiState.menuDeviceAddress);
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
