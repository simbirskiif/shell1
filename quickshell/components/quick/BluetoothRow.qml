import QtQuick
import ".."
import "../../singletons"

// Строка Bluetooth-устройства: значок устройства слева, подключённое
// обведено кольцом, справа — заряд (если BlueZ его отдаёт) и индикатор
// подключения.
Rectangle {
    id: root

    required property string name
    required property string icon
    required property string address
    required property bool connected
    required property bool connecting
    // Процент заряда или -1, если данных нет: строка показывается только
    // для подключённых устройств с Battery1.
    property int batteryPercent: -1

    signal activated()
    // Правый клик: контекстное меню (подключиться/отключиться, удалить).
    // Координаты — локальные для окна панели: меню живёт в том же окне.
    signal contextRequested(real x, real y)

    // m3 divider между строками списка: у последней строки линии нет.
    readonly property bool separatorVisible: ListView.view !== null
        && (root.y + root.height) < ListView.view.contentHeight

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.listItemHeight
    // Состояние M3: прозрачный контейнер, hover — state layer поверх.
    color: rowHover.containsMouse && !root.connecting
           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    // Пока идёт подключение, меню не открывается: операция уже в работе.
    readonly property bool showBattery: root.batteryPercent >= 0

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.connecting
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                const topLeft = root.mapToItem(null, 0, 0);
                root.contextRequested(topLeft.x + mouse.x, topLeft.y + mouse.y);
                return;
            }
            root.activated();
        }
    }

    PanelIcon {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        connected: root.connected
    }

    Text {
        id: nameText
        anchors.left: iconSlot.right
        anchors.leftMargin: Theme.space.md
        // Заряд уходит вправо, поэтому имя не должно заезжать под него.
        anchors.right: root.showBattery ? batteryText.left : spinnerSlot.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.name
        color: Theme.scheme.onSurface
        font: Theme.typeBodyLarge
    }

    // Заряд: только когда он реально известен (подключённое устройство
    // с интерфейсом org.bluez.Battery1).
    Text {
        id: batteryText
        anchors.right: spinnerSlot.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showBattery
        text: root.batteryPercent + "%"
        color: Theme.scheme.onSurfaceVariant
        font: Theme.typeBodyMedium
    }

    LoadingIndicator {
        id: spinnerSlot
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize.sm
        height: Theme.iconSize.sm
        visible: root.connecting
    }

    // Разделитель m3: outline-variant, толщина 1, отступ 16 по краям.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        height: 1
        color: Theme.outlineVariant
        visible: root.separatorVisible
    }
}
