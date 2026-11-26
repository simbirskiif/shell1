import QtQuick
import "../../singletons"

// Раздел «Бар»: живое превью правой части бара, добавление/удаление
// перетаскиванием и запуск отдельного окна выбора иконки.
SettingsPage {
    id: root

    property string selectedKey: MockState.firstBarItemKey()

    // Состояние переноса. Координаты — в системе страницы; BarPreview
    // переводит их в свои локальные и сообщает позицию вставки.
    property string dragKey: ""
    property bool dragFromBar: false
    property int dragFromIndex: -1
    property bool dragMoved: false
    property point dragStart: Qt.point(0, 0)
    property point dragPoint: Qt.point(0, 0)
    property string dropMode: ""
    property int dropGap: -1

    readonly property real dragDeltaX: dragPoint.x - dragStart.x
    readonly property real dragDeltaY: dragPoint.y - dragStart.y

    title: I18n.tr("settings.bar.title")
    description: I18n.tr("settings.bar.description")

    Component.onCompleted: {
        if (!MockState.barItemPresent(root.selectedKey))
            root.selectedKey = MockState.firstBarItemKey();
    }

    Connections {
        target: MockState

        // Элемент могли убрать снаружи (IPC, сброс).
        function onBarRevisionChanged() {
            if (!MockState.barItemPresent(root.selectedKey))
                root.selectedKey = MockState.firstBarItemKey();
        }
    }

    function titleFor(key) {
        return I18n.trOr("bar.item." + key, MockState.barItemTitles[key] || key);
    }

    function beginDrag(key, fromBar, index, x, y) {
        root.dragKey = key;
        root.dragFromBar = fromBar;
        root.dragFromIndex = index;
        root.dragMoved = false;
        root.dragStart = Qt.point(x, y);
        root.dragPoint = root.dragStart;
        root.dropMode = "";
        root.dropGap = -1;
        preview.dropGap = -1;
        if (fromBar)
            root.selectedKey = key;
    }

    function updateDrag(x, y) {
        if (root.dragKey === "")
            return;
        root.dragPoint = Qt.point(x, y);
        if (!root.dragMoved) {
            const dx = root.dragPoint.x - root.dragStart.x;
            const dy = root.dragPoint.y - root.dragStart.y;
            if (Math.sqrt(dx * dx + dy * dy) < 4)
                return;
            root.dragMoved = true;
        }

        const point = preview.mapFromItem(root, x, y);
        const inside = point.x >= 0 && point.x <= preview.width
                       && point.y >= 0 && point.y <= preview.height;
        root.dropMode = inside ? "bar" : "";
        root.dropGap = inside ? preview.gapAt(point.x) : -1;
        preview.dropGap = root.dropGap;
    }

    function resetDrag() {
        root.dragKey = "";
        root.dragFromBar = false;
        root.dragFromIndex = -1;
        root.dragMoved = false;
        root.dropMode = "";
        root.dropGap = -1;
        preview.dropGap = -1;
    }

    function finishDrag() {
        const key = root.dragKey;
        const fromBar = root.dragFromBar;
        const fromIndex = root.dragFromIndex;
        const moved = root.dragMoved;
        const mode = root.dropMode;
        const gap = root.dropGap;
        root.resetDrag();

        if (key === "")
            return;

        // Короткий клик по элементу бара — окно выбора иконки.
        if (!moved) {
            if (fromBar)
                SettingsWindowState.openIconEditor(key);
            return;
        }

        if (mode === "bar" && gap >= 0) {
            if (fromBar) {
                let to = gap > fromIndex ? gap - 1 : gap;
                to = Math.max(0, Math.min(MockState.barItems.count - 1, to));
                if (to !== fromIndex)
                    MockState.moveBarItemTo(fromIndex, to);
                root.selectedKey = key;
            } else {
                MockState.addBarItemAt(key, gap);
                root.selectedKey = key;
            }
            return;
        }

        // Вытащили элемент из бара — убираем. Последний элемент не трогаем,
        // чтобы не остаться без входа в настройки.
        if (fromBar && MockState.barItems.count > 1) {
            MockState.removeBarItem(key);
            root.selectedKey = MockState.firstBarItemKey();
        }
    }

    function addItem(key) {
        MockState.addBarItem(key);
        root.selectedKey = key;
    }

    SettingsCard {
        title: I18n.tr("settings.bar.right.title")
        description: I18n.tr("settings.bar.right.description")

        BarPreview {
            id: preview

            width: parent.width
            selectedKey: root.selectedKey
            dragLayer: root
            draggingKey: root.dragKey
            dragDeltaX: root.dragDeltaX
            dragDeltaY: root.dragDeltaY

            onSelected: key => root.selectedKey = key
            onDragStarted: (key, index, x, y) => root.beginDrag(key, true, index, x, y)
            onDragMoved: (x, y) => root.updateDrag(x, y)
            onDragFinished: root.finishDrag()
            onDragCanceled: root.resetDrag()
        }

        SettingsSwitchRow {
            title: I18n.tr("settings.bar.batteryPercent.title")
            description: I18n.tr("settings.bar.batteryPercent.description")
            checked: MockState.showBatteryPercent
            onToggled: MockState.showBatteryPercent = !MockState.showBatteryPercent
        }

        Text {
            width: parent.width
            visible: root.dragMoved && root.dragFromBar
            text: root.dropMode === "bar"
                  ? I18n.tr("settings.bar.dropMove")
                  : I18n.tr("settings.bar.dropRemove")
            color: root.dropMode === "bar" ? Theme.primary : Theme.warningColor
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: MockState.barItems.count === 0
            text: I18n.tr("settings.bar.empty")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    SettingsCard {
        title: I18n.tr("settings.bar.add.title")
        description: I18n.tr("settings.bar.add.description")

        Repeater {
            model: MockState.availableBarItems()

            delegate: Item {
                id: availableRow

                required property string modelData

                width: parent.width
                height: Theme.touchTarget
                z: root.dragKey === modelData ? 50 : 0

                // Содержимое строки едет за мышью; слот и кнопка остаются.
                Item {
                    id: availableVisual

                    anchors.left: parent.left
                    anchors.right: addButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    transform: Translate {
                        x: root.dragKey === modelData ? root.dragDeltaX : 0
                        y: root.dragKey === modelData ? root.dragDeltaY : 0
                    }

                    Text {
                        id: availableIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.space.xl
                        text: MockState.barItemIcon(modelData)
                        color: Theme.scheme.onSurfaceVariant
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize.md
                    }

                    Text {
                        anchors.left: availableIcon.right
                        anchors.leftMargin: Theme.space.md
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.titleFor(modelData)
                        color: Theme.scheme.onSurface
                        font: Theme.typeBodyLarge
                        elide: Text.ElideRight
                    }
                }

                SettingsButton {
                    id: addButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("common.add")
                    variant: "tonal"
                    onClicked: root.addItem(modelData)
                }

                // Тянем только за подпись: кнопка «Добавить» остаётся
                // кликабельной и не мешает перетаскиванию.
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: addButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property real pressX: 0
                    property real pressY: 0
                    property bool moved: false

                    function pagePoint(x, y) {
                        return root.mapFromItem(availableRow, x, y);
                    }

                    onPressed: mouse => {
                        pressX = mouse.x;
                        pressY = mouse.y;
                        moved = false;
                        const point = pagePoint(mouse.x, mouse.y);
                        root.beginDrag(modelData, false, -1, point.x, point.y);
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
                        root.updateDrag(point.x, point.y);
                    }

                    onReleased: root.finishDrag()
                    onCanceled: root.resetDrag()
                }
            }
        }

        Text {
            width: parent.width
            visible: MockState.availableBarItems().length === 0
            text: I18n.tr("settings.bar.allAdded")
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
        }
    }

    Row {
        spacing: Theme.space.sm

        SettingsButton {
            text: I18n.tr("settings.bar.resetIcons")
            variant: "outlined"
            onClicked: MockState.resetBarIcons()
        }

        SettingsButton {
            text: I18n.tr("settings.bar.reset")
            variant: "outlined"
            onClicked: {
                MockState.resetBarSettings();
                root.selectedKey = MockState.firstBarItemKey();
            }
        }
    }
}
