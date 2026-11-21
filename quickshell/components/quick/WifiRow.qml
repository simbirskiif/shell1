import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Строка сети Wi-Fi: значок сети слева, справа — состояние:
// индикатор подключения, «!» если нужны доп. действия (сертификат и т.п.)
// или замок для сети с паролем.
//
// Expressive: строка — крупная пилюля. Подключённая сеть залита
// primary-container, обычная — прозрачная с hover-слоем; иконка-орб 42
// у подключённой превращается в «печенье» на tertiary-container.
// Разделителей между строками нет: ряды разделяет воздух.
Item {
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

    // Подключённой сеть выглядит только при включённом Wi-Fi: иначе после
    // выключения радио строка ещё висела залитой.
    readonly property bool shownConnected: root.connected && NetworkService.wifiEnabled

    readonly property bool needsExtra: root.security === "enterprise"
    readonly property bool needsPassword: root.security === "psk"

    readonly property bool hovered: rowHover.containsMouse && !root.connecting
    readonly property bool pressed: rowHover.pressed && !root.connecting

    // Цвет контейнера строки: подключённая — primary-container, иначе
    // прозрачно (цвет проявляет hover-слой).
    readonly property color rowColor: root.shownConnected ? Theme.primaryContainer
                                     : root.hovered ? Theme.surfaceContainerHigh
                                     : "transparent"
    readonly property color ink: root.shownConnected ? Theme.scheme.onPrimaryContainer
                                                : Theme.scheme.onSurface

    width: ListView.view ? ListView.view.width : implicitWidth
    height: 62

    scale: root.pressed ? 0.98 : 1
    Behavior on scale { SpringSpatialFast {} }

    // Фон-пилюля: у подключённой сети контур пилюли, у остальных hover
    // деформирует squircle — состояние читается формой, а не линией.
    MorphShape {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        shape: root.shownConnected ? "pill" : "squircle"
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
                if (!root.saved)
                    return;
                const topLeft = root.mapToItem(null, 0, 0);
                root.contextRequested(topLeft.x + mouse.x, topLeft.y + mouse.y);
                return;
            }
            root.activated();
        }
    }

    // Орб доступности сети: деления сигнала; у подключённой — «печенье»
    // tertiary-контейнера, у остальных — круг на тональной поверхности.
    WifiStatusIcon {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 42
        showRing: true
        connected: root.shownConnected
        signal: root.strength
        glyphSize: 20
        ringColor: root.shownConnected ? Theme.tertiaryContainer : Theme.surfaceContainerHighest
        ringInk: root.shownConnected ? Theme.scheme.onTertiaryContainer : Theme.scheme.onSurfaceVariant
        connectedShape: "cookie"
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
        color: root.ink
        font: root.shownConnected ? Theme.typeEmphasizedLabelLarge : Theme.typeBodyLarge
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    LoadingIndicator {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize.md
        height: Theme.iconSize.md
        visible: root.connecting
        accent: root.shownConnected ? Theme.scheme.onPrimaryContainer : Theme.primary
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.connecting && root.needsExtra
        text: "\uf06a"
        color: root.shownConnected ? Theme.scheme.onPrimaryContainer : Theme.warning
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.connecting && !root.needsExtra && root.needsPassword
        text: "\uf023"
        color: root.shownConnected ? Theme.withAlpha(Theme.scheme.onPrimaryContainer, 0.8)
                              : Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
    }
}
