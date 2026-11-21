import QtQuick
import ".."
import "../../singletons"

// Строка сети Wi-Fi: значок сети слева, справа — состояние:
// индикатор подключения, «!» если нужны доп. действия (сертификат и т.п.)
// или замок для сети с паролем.
Rectangle {
    id: root

    required property string name
    required property int strength
    required property string security
    required property bool saved
    required property bool connected
    required property bool connecting

    signal activated()
    // Правый клик: контекстное меню (сменить пароль / забыть). Только для
    // сохранённых сетей — у остальных менять нечего. Координаты — локальные
    // для окна панели: меню живёт в том же окне, что и панель.
    signal contextRequested(real x, real y)

    // Строка выглядит подключённой только при включённом Wi-Fi.
    readonly property bool shownConnected: root.connected && NetworkService.wifiEnabled

    readonly property bool needsExtra: root.security === "enterprise"
    readonly property bool needsPassword: root.security === "psk"

    // m3 divider между строками списка: у последней строки линии нет,
    // поэтому она не «закрывает» список снизу.
    readonly property bool separatorVisible: ListView.view !== null
        && (root.y + root.height) < ListView.view.contentHeight

    width: ListView.view ? ListView.view.width : implicitWidth
    height: Theme.listItemHeight
    // Состояние M3: контейнер строки прозрачный, hover — state layer поверх.
    color: rowHover.containsMouse && !root.connecting
           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.connecting
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (!root.saved)
                    return;
                const topLeft = root.mapToItem(null, 0, 0);
                root.contextRequested(topLeft.x + mouse.x, topLeft.y + mouse.y);
                return;
            }
            root.activated();
        }
    }

    // Круглая иконка как у строк Bluetooth: слева — доступность сети
    // (деления по сигналу), у подключённой — подложка и кольцо. Замок для
    // сети с паролем показывается справа.
    WifiStatusIcon {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        showRing: true
        connected: root.shownConnected
        signal: root.strength
        glyphSize: Theme.iconSize.sm
    }

    Text {
        anchors.left: iconSlot.right
        anchors.leftMargin: Theme.space.md
        // Справа — место под индикатор состояния (16 отступ + 24 иконка):
        // длинное имя сети не заезжает под замок/спиннер.
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.xl + Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.name
        color: Theme.scheme.onSurface
        font: Theme.typeBodyLarge
    }

    LoadingIndicator {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize.sm
        height: Theme.iconSize.sm
        visible: root.connecting
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.connecting && root.needsExtra
        text: "\uf06a"
        color: Theme.warning
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.connecting && !root.needsExtra && root.needsPassword
        text: "\uf023"
        color: Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
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
