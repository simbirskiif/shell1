import QtQuick
import ".."
import "../quick"
import "../player"
import "../../singletons"

// Живое превью правой части бара: те же кнопки, что в настоящем баре,
// с настоящими значениями сервисов.
//
// Перетаскивание обрабатывает страница настроек (единое перетаскивание для бара и списка
// доступных действий); здесь остаются выбор кликом, приём цели и маркер
// вставки.
Item {
    id: root

    property string selectedKey: "battery"
    // Куда встанет перетаскиваемый элемент: 0..count; -1 — маркер скрыт.
    property int dropGap: -1
    // Item, в координатах которого страница считает позицию курсора.
    property Item dragLayer: null

    // Перетаскиваемый элемент и его смещение: видимая кнопка едет за мышью,
    // слот в Row остаётся на месте.
    property string draggingKey: ""
    property real dragDeltaX: 0
    property real dragDeltaY: 0

    signal selected(string key)
    signal dragStarted(string key, int index, real x, real y)
    signal dragMoved(real x, real y)
    signal dragFinished()
    signal dragCanceled()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.barHeight + Theme.space.md

    // Позиция вставки по локальной X превью. Сравниваем с центрами кнопок:
    // левее центра первой — 0, правее центра последней — count.
    function gapAt(localX) {
        const rowX = localX - previewRow.x;
        if (previewRepeater.count === 0)
            return 0;
        for (let i = 0; i < previewRepeater.count; ++i) {
            const item = previewRepeater.itemAt(i);
            if (rowX < item.x + item.width / 2)
                return i;
        }
        return previewRepeater.count;
    }

    function markerX() {
        if (root.dropGap < 0)
            return 0;
        if (previewRepeater.count === 0)
            return width / 2;
        if (root.dropGap <= 0)
            return previewRow.x + previewRepeater.itemAt(0).x - previewRow.spacing / 2;
        if (root.dropGap >= previewRepeater.count) {
            const last = previewRepeater.itemAt(previewRepeater.count - 1);
            return previewRow.x + last.x + last.width + previewRow.spacing / 2;
        }
        return previewRow.x + previewRepeater.itemAt(root.dropGap).x - previewRow.spacing / 2;
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
            spacing: Theme.barIconGap

            Repeater {
                id: previewRepeater

                model: MockState.barItems

                delegate: Item {
                    id: chip

                    required property string itemKey
                    required property int index

                    readonly property bool selected: root.selectedKey === itemKey

                    width: previewLoader.implicitWidth + Theme.space.md
                    height: Theme.barIconSlot + Theme.space.sm
                    z: root.draggingKey === itemKey ? 50 : 0

                    // Выделение выбранного. Дроп-цель показывает отдельный
                    // вертикальный маркер ниже.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shape.full
                        color: chip.selected
                               ? Theme.withAlpha(Theme.primary, 0.10)
                               : (dragArea.containsMouse
                                  ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                                  : "transparent")
                        border.width: chip.selected ? 1 : 0
                        border.color: Theme.primary
                    }

                    Item {
                        id: visual

                        anchors.fill: parent
                        transform: Translate {
                            x: root.draggingKey === chip.itemKey ? root.dragDeltaX : 0
                            y: root.draggingKey === chip.itemKey ? root.dragDeltaY : 0
                        }

                        Loader {
                            id: previewLoader

                            anchors.centerIn: parent
                            sourceComponent: chip.itemKey === "battery" ? batteryPreview
                                           : chip.itemKey === "notifications" ? notificationsPreview
                                           : chip.itemKey === "status" ? statusPreview
                                           : chip.itemKey === "wifi" ? wifiPreview
                                           : chip.itemKey === "bluetooth" ? bluetoothPreview
                                           : chip.itemKey === "brightness" ? brightnessPreview
                                           : chip.itemKey === "sound" ? soundPreview
                                           : chip.itemKey === "privacy" ? privacyPreview
                                           : playerPreview
                        }
                    }

                    // Клик открывает окно иконки, движение — перетаскивание.
                    // События уходят странице, чтобы она могла принять drop
                    // и добавить/убрать элемент.
                    MouseArea {
                        id: dragArea

                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property real pressX: 0
                        property real pressY: 0
                        property bool moved: false

                        function pagePoint(x, y) {
                            return root.dragLayer
                                ? root.dragLayer.mapFromItem(chip, x, y)
                                : Qt.point(x, y);
                        }

                        onPressed: mouse => {
                            pressX = mouse.x;
                            pressY = mouse.y;
                            moved = false;
                            root.selected(chip.itemKey);
                            const point = pagePoint(mouse.x, mouse.y);
                            root.dragStarted(chip.itemKey, chip.index, point.x, point.y);
                        }

                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            if (!moved
                                    && Math.sqrt((mouse.x - pressX) * (mouse.x - pressX)
                                      + (mouse.y - pressY) * (mouse.y - pressY)) < 4)
                                return;
                            moved = true;
                            const point = pagePoint(mouse.x, mouse.y);
                            root.dragMoved(point.x, point.y);
                        }

                        onReleased: root.dragFinished()
                        onCanceled: root.dragCanceled()
                    }
                }
            }
        }

        // Вертикальный маркер места вставки.
        Rectangle {
            visible: root.dropGap >= 0
            x: root.markerX() - width / 2
            y: previewRow.y + (previewRow.height - height) / 2
            width: 2
            height: 32
            radius: Theme.shape.full
            color: Theme.primary
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
            bluetoothIcon: MockState.statusIconFor("bluetooth")
            wifiIcon: MockState.statusIconFor("wifi")
            soundIcon: MockState.statusIconFor("sound")
            bluetoothEnabled: BluetoothBackend.enabled
            wifiEnabled: NetworkService.wifiEnabled
            wifiConnected: NetworkService.wifiConnected
            wifiSignal: NetworkService.connectedSignal
            soundEnabled: !AudioService.outputMuted
            opened: false
        }
    }

    Component {
        id: wifiPreview

        BarActionButton {
            kind: "wifi"
            iconOverride: MockState.iconFor("wifi")
            wifiEnabled: NetworkService.wifiEnabled
            wifiConnected: NetworkService.wifiConnected
            wifiSignal: NetworkService.connectedSignal
        }
    }

    Component {
        id: bluetoothPreview

        BarActionButton {
            kind: "bluetooth"
            iconOverride: MockState.iconFor("bluetooth")
            bluetoothEnabled: BluetoothBackend.enabled
        }
    }

    Component {
        id: brightnessPreview

        BarActionButton {
            kind: "brightness"
            iconOverride: MockState.iconFor("brightness")
        }
    }

    Component {
        id: soundPreview

        BarActionButton {
            kind: "sound"
            iconOverride: MockState.iconFor("sound")
        }
    }

    Component {
        id: privacyPreview

        PrivacyIndicator {
            previewMode: true
            iconOverride: MockState.iconFor("privacy")
        }
    }

    Component {
        id: playerPreview

        PlayerBarButton {
            iconOverride: MockState.iconFor("player")
        }
    }
}
