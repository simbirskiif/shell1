import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../../singletons"
import "."

// Окно дока: одна layer-shell поверхность постоянного размера у нижней
// кромки экрана. Содержимое (Dock.qml) живёт внутри и свободно меняет
// размер; сама поверхность не ресайзится, поэтому анимации не зависят от
// того, как быстро композитор пересоздаёт буфер.
//
// Ввод ограничен маской: зона активации + текущая карточка. Всё остальное
// прозрачно и пропускает клики в окна под доком.
PanelWindow {
    id: root

    required property ShellScreen dockScreen

    readonly property string screenName: root.dockScreen ? root.dockScreen.name : ""
    readonly property bool active: DockState.screenName === root.screenName

    // Маску во время перехода фиксируем на целевой геометрии: курсор не
    // должен «выпадать» из поверхности, пока карточка ещё едет.
    property rect frozenCard: Qt.rect(0, 0, 0, 0)

    readonly property rect targetCard: Qt.rect(
        Math.round((root.width - dock.targetWidth) / 2),
        Math.round(root.height - Theme.dockBottomMargin - dock.targetHeight),
        Math.round(dock.targetWidth),
        Math.round(dock.targetHeight))

    readonly property rect cardMask: {
        if (!root.active || DockState.phase === "hidden")
            return Qt.rect(0, 0, 0, 0);
        if (DockState.phase === "hiding")
            return root.frozenCard;
        if (DockState.phase === "showing"
                || DockState.phase === "expanding"
                || DockState.phase === "collapsing")
            return root.targetCard;
        return Qt.rect(dock.x, dock.y, dock.width, dock.height);
    }

    // Раскрытие и сжатие делают размер карточки, а не окна: границы маски
    // меняются только на смене фазы, не на каждом кадре.
    Connections {
        target: DockState

        function onPhaseChanged() {
            if (DockState.phase === "hiding" && DockState.screenName === root.screenName)
                root.frozenCard = Qt.rect(Math.round(dock.x), Math.round(dock.y),
                                          Math.round(dock.width), Math.round(dock.height));
        }
    }

    screen: root.dockScreen
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Math.min(root.screen ? root.screen.height : Theme.dockSurfaceHeight,
                             Theme.dockSurfaceHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Подсказка у нижней кромки, пока док спрятан: иначе зону активации
    // пришлось бы искать вслепую. Она не перехватывает клики.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: 44
        height: 3
        radius: height / 2
        color: Theme.quickText
        opacity: DockState.phase === "hidden" ? 0.22 : 0
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionShort4
                curve: Theme.curveStandard
            }
        }
    }

    mask: Region {
        intersection: Intersection.Combine

        // Зона активации: узкая полоса по центру нижней кромки. Ограничена
        // по ширине, чтобы не мешать тянуть границы окон в углах.
        Region {
            x: Math.round((root.width - Math.min(root.width, Theme.dockActivationWidth)) / 2)
            y: root.height - Theme.dockActivationHeight
            width: Math.round(Math.min(root.width, Theme.dockActivationWidth))
            height: Theme.dockActivationHeight
        }

        // Карточка. Нулевой размер в скрытом состоянии — ввода там нет.
        // Полосу под карточкой (нижний отступ) тоже включаем в маску: иначе
        // при подъёме курсора из зоны активации к иконкам он на несколько
        // пикселей выпадает из поверхности и док успевает начать скрываться.
        Region {
            x: root.cardMask.x
            y: root.cardMask.y
            width: root.cardMask.width
            height: root.cardMask.height > 0 ? root.height - root.cardMask.y : 0
        }
    }

    // Пассивный обработчик: он не забирает клики у кнопок внутри, но видит
    // курсор в любой точке маски — и над зоной активации, и над карточкой.
    HoverHandler {
        id: pointer

        onHoveredChanged: {
            if (pointer.hovered) {
                DockState.pointerEntered(root.screenName);
                return;
            }
            if (DockState.screenName === root.screenName)
                DockState.pointerExited();
        }
    }

    Dock {
        id: dock
        screenName: root.screenName
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dockBottomMargin
    }
}
