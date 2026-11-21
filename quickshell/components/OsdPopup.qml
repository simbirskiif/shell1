import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "expressive"
import "../singletons"

// Общая оболочка нижних всплывашек: окно-оверлей внизу экрана, выезд снизу,
// затухание, автоскрытие после того, как shown станет false, и снятие
// поверхности только после анимации ухода.
//
// Содержимое кладётся дочерними элементами и занимает всю карточку:
//
//   OsdPopup {
//       shown: SomeService.visible
//       cardWidth: 520
//       cardHeight: 44
//       // ... любые элементы; родитель — вся площадь карточки
//   }
//
// Показывается на экране с фокусом (если Hyprland молчит — на первом).
PanelWindow {
    id: root

    // Кто просит показать. Владелец (сервис или панель) решает, когда.
    property bool shown: false

    // Размер карточки задаёт содержимое. Окно выше карточки на запас под
    // выезд, поэтому сдвиг карточки не обрезается.
    property real cardWidth: 520
    property real cardHeight: 44
    property real slideDistance: 26

    // Содержимое карточки.
    default property alias content: contentHost.data

    // Экран задаёт делегат Variants (screen: modelData).
    anchors.bottom: true
    margins.bottom: 72

    implicitWidth: root.cardWidth + 40
    implicitHeight: root.cardHeight + root.slideDistance + 20
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.focusable: false

    readonly property string focusedMonitorName: {
        const monitor = Hyprland.focusedMonitor;
        return (monitor === null || monitor === undefined) ? "" : monitor.name;
    }

    readonly property bool onFocusedScreen: root.focusedMonitorName !== ""
        ? (root.screen !== null && root.screen.name === root.focusedMonitorName)
        : (Quickshell.screens.length > 0 && root.screen === Quickshell.screens[0])

    // Окно снимаем с экрана только после анимации ухода.
    property bool keepingAlive: false
    visible: (root.shown || root.keepingAlive) && root.onFocusedScreen

    Connections {
        target: root

        function onShownChanged() {
            if (root.shown) {
                root.keepingAlive = true;
                exitTimer.stop();
            } else {
                exitTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        if (root.shown)
            root.keepingAlive = true;
    }

    Timer {
        id: exitTimer
        interval: 260
        onTriggered: root.keepingAlive = false
    }

    // Скругление должно обрезать и содержимое (волнистый слайдер), поэтому
    // это ClippingRectangle, а не Rectangle с clip: обычный clip режет по
    // прямоугольнику, и на нижних скруглённых углах торчали квадратные углы.
    ClippingRectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.cardWidth
        height: root.cardHeight
        // Expressive-пилюля: радиус — половина высоты, без обводки.
        // Тональная поверхность та же, что у остальных всплывашек.
        radius: height / 2
        contentInsideBorder: false
        color: Theme.sheetSurface

        // Появление — пружины: прозрачность effects-пружиной (без перелёта),
        // выезд снизу — spatial-пружиной с лёгким перелётом.
        opacity: root.shown ? 1 : 0
        Behavior on opacity { SpringEffects {} }

        transform: Translate {
            y: root.shown ? 0 : root.slideDistance
            Behavior on y { SpringSpatial {} }
        }

        Item {
            id: contentHost
            anchors.fill: parent
        }
    }
}
