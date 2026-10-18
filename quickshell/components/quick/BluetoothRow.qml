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

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.quickRowHeight
    color: rowHover.hovered && !root.connecting ? Theme.quickTileHover : "transparent"
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
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        connected: root.connected
    }

    Text {
        id: nameText
        anchors.left: iconSlot.right
        anchors.leftMargin: 12
        // Заряд уходит вправо, поэтому имя не должно заезжать под него.
        anchors.right: root.showBattery ? batteryText.left : spinnerSlot.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.name
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    // Заряд: только когда он реально известен (подключённое устройство
    // с интерфейсом org.bluez.Battery1).
    Text {
        id: batteryText
        anchors.right: spinnerSlot.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showBattery
        text: root.batteryPercent + "%"
        color: Theme.quickTextDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    LoadingIndicator {
        id: spinnerSlot
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        visible: root.connecting
    }
}
