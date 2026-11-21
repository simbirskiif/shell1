import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка Bluetooth-устройства: значок устройства слева, подключённое
// выделено крупной пилюлей, справа — заряд (если BlueZ его отдаёт) и
// индикатор подключения.
//
// Expressive: подключённое устройство — tertiary-container пилюля, орб 42
// с формой «клевер»; остальные строки прозрачные с hover-слоем squircle.
// Тонких разделителей нет.
Item {
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

    readonly property bool showBattery: root.batteryPercent >= 0
    readonly property bool hovered: rowHover.containsMouse && !root.connecting
    readonly property bool pressed: rowHover.pressed && !root.connecting

    readonly property color rowColor: root.connected ? Theme.tertiaryContainer
                                     : root.hovered ? Theme.surfaceContainerHigh
                                     : "transparent"
    readonly property color ink: root.connected ? Theme.scheme.onTertiaryContainer
                                                : Theme.scheme.onSurface

    width: ListView.view ? ListView.view.width : implicitWidth
    height: 62

    scale: root.pressed ? 0.98 : 1
    Behavior on scale { SpringSpatialFast {} }

    MorphShape {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        shape: root.connected ? "pill" : "squircle"
        color: root.rowColor
        modulation: 0.35

        Behavior on color { ColorAnimation { duration: 140 } }
    }

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

    // Орб устройства: выключенное — круг на тональной поверхности,
    // подключённое — «клевер» primary-контейнера внутри tertiary-строки.
    MorphShape {
        id: iconOrb
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 42
        shape: root.connected ? "clover" : "circle"
        color: root.connected ? Theme.primaryContainer : Theme.surfaceContainerHighest
        modulation: 1

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.connected ? Theme.scheme.onPrimaryContainer
                                  : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 20
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    Text {
        id: nameText
        anchors.left: iconOrb.right
        anchors.leftMargin: Theme.space.md
        // Заряд уходит вправо, поэтому имя не должно заезжать под него.
        anchors.right: root.showBattery ? batteryText.left : spinnerSlot.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.name
        color: root.ink
        font: root.connected ? Theme.typeEmphasizedLabelLarge : Theme.typeBodyLarge
        Behavior on color { ColorAnimation { duration: 140 } }
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
        color: root.connected ? Theme.withAlpha(Theme.scheme.onTertiaryContainer, 0.85)
                              : Theme.scheme.onSurfaceVariant
        font: Theme.typeLabelLarge
    }

    LoadingIndicator {
        id: spinnerSlot
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize.md
        height: Theme.iconSize.md
        visible: root.connecting
        accent: root.connected ? Theme.scheme.onTertiaryContainer : Theme.primary
    }

    // Раскрывающаяся пилюля под список «ещё» — без разделителя.
}
