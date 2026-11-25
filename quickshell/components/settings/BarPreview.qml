import QtQuick
import ".."
import "../quick"
import "../../singletons"

// Живое превью правой части бара: те же кнопки, что в настоящем баре,
// с настоящими значениями сервисов. Элементы выбираются кликом, а
// перетаскивание меняет их порядок после отпускания.
//
// Repeater с ListModel пересоздаёт делегаты на move(), поэтому во время
// перетаскивания модель не трогаем: показываем цель и смещаем только
// отрисовку, а move() вызываем один раз на отпускании.
Item {
    id: root

    property string selectedKey: "battery"
    property int dragIndex: -1
    property int dropIndex: -1
    property real dragOffset: 0

    signal selected(string key)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.barHeight + Theme.space.md

    function targetIndex(rowX) {
        let target = previewRepeater.count - 1;
        for (let i = 0; i < previewRepeater.count; ++i) {
            const item = previewRepeater.itemAt(i);
            if (item && rowX < item.x + item.width / 2) {
                target = i;
                break;
            }
        }
        return target;
    }

    function resetDrag() {
        root.dragIndex = -1;
        root.dropIndex = -1;
        root.dragOffset = 0;
    }

    // Полоса как у бара: тот же фон, высота и отступ справа.
    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.lg
        color: Theme.barBackground
        border.width: 1
        border.color: Theme.outlineVariant

        Row {
            id: previewRow

            anchors.right: parent.right
            anchors.rightMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                id: previewRepeater

                model: MockState.barItems

                delegate: Item {
                    id: chip

                    required property string itemKey
                    required property int index

                    readonly property bool selected: root.selectedKey === itemKey
                    readonly property bool dropTarget: root.dropIndex === index
                                                      && root.dragIndex >= 0
                                                      && root.dropIndex !== root.dragIndex

                    width: previewLoader.implicitWidth + Theme.space.md
                    height: Theme.iconButtonSize + Theme.space.sm
                    z: root.dragIndex === index ? 10 : 0

                    // Выделение выбранного и подсветка цели перетаскивания.
                    // Остаётся на месте слота, пока содержимое едет за мышью.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shape.full
                        color: chip.dropTarget
                               ? Theme.withAlpha(Theme.primary, 0.18)
                               : chip.selected
                                 ? Theme.withAlpha(Theme.primary, 0.10)
                                 : (dragArea.containsMouse
                                    ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                    : "transparent")
                        border.width: chip.dropTarget ? 2 : (chip.selected ? 1 : 0)
                        border.color: Theme.primary
                    }

                    Item {
                        id: visual

                        anchors.fill: parent
                        transform: Translate {
                            x: root.dragIndex === chip.index ? root.dragOffset : 0
                        }

                        Loader {
                            id: previewLoader

                            anchors.centerIn: parent
                            sourceComponent: chip.itemKey === "battery" ? batteryPreview
                                           : chip.itemKey === "notifications" ? notificationsPreview
                                           : statusPreview
                        }
                    }

                    // Клики и перетаскивание: перекрываем действие настоящей
                    // кнопки, чтобы в настройках она только выбиралась.
                    MouseArea {
                        id: dragArea

                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property real pressX: 0

                        onPressed: {
                            root.dragIndex = chip.index;
                            root.dropIndex = chip.index;
                            root.dragOffset = 0;
                            pressX = mouse.x;
                            root.selectedKey = chip.itemKey;
                            root.selected(chip.itemKey);
                        }

                        onPositionChanged: mouse => {
                            if (root.dragIndex < 0)
                                return;
                            root.dragOffset = mouse.x - pressX;
                            const point = mapToItem(previewRow, mouse.x, mouse.y);
                            root.dropIndex = root.targetIndex(point.x);
                        }

                        onReleased: {
                            const from = root.dragIndex;
                            const to = root.dropIndex;
                            root.resetDrag();
                            if (from >= 0 && to >= 0 && from !== to)
                                Qt.callLater(() => MockState.moveBarItemTo(from, to));
                        }

                        onCanceled: root.resetDrag()
                    }
                }
            }
        }
    }

    Component {
        id: batteryPreview

        BatteryButton {
            level: PowerService.level
            charging: PowerService.charging
            showPercent: MockState.showBatteryPercent
            iconOverride: MockState.iconFor("battery")
        }
    }

    Component {
        id: notificationsPreview

        NotificationButton {
            iconGlyph: MockState.iconFor("notifications")
        }
    }

    Component {
        id: statusPreview

        ControlButton {
            iconOverride: MockState.iconFor("status")
            bluetoothEnabled: BluetoothBackend.enabled
            wifiEnabled: NetworkService.wifiEnabled
            wifiConnected: NetworkService.wifiConnected
            wifiSignal: NetworkService.connectedSignal
            soundEnabled: !AudioService.outputMuted
            opened: false
        }
    }
}
