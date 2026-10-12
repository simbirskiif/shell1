import QtQuick
import ".."
import Quickshell
import "../../singletons"

// Выпадающая панель быстрых настроек под кнопкой статуса в баре.
// Ширина ограничена темой, высота следует за содержимым с анимацией —
// вместе с кроссфейдом видов это даёт плавное «раскрытие» внутрь.
PopupWindow {
    id: root

    required property PanelWindow anchorWindow

    readonly property string screenName: anchorWindow.screen ? anchorWindow.screen.name : ""

    // Источник правды — UiState. visible выставляем руками, а не биндингом:
    // окно может погасить и сам композитор (grabFocus при клике мимо),
    // тогда мы просто синхронизируем состояние обратно.
    visible: false
    grabFocus: true

    function toggle() {
        UiState.toggle(root.screenName);
    }

    function close() {
        UiState.close();
    }

    function syncVisibility() {
        root.visible = UiState.openedScreen === root.screenName;
    }

    onVisibleChanged: {
        if (!root.visible && UiState.openedScreen === root.screenName)
            UiState.close();
    }

    Connections {
        target: UiState

        function onOpenedScreenChanged() {
            root.syncVisibility();
        }
    }

    Component.onCompleted: {
        root.syncVisibility();
        UiState.popupHeight = root.implicitHeight;
    }

    // Публикуем текущую высоту — видно из qs ipc call bar state.
    onImplicitHeightChanged: UiState.popupHeight = root.implicitHeight

    // Правый верхний угол попапа — под кнопкой в баре, растёт вниз-влево.
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width - Theme.barPadding
    anchor.rect.y: anchorWindow.height + 4
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left

    color: "transparent"

    // Панель не должна вылезать за экран: высоту ограничиваем,
    // а содержимое уходит в прокрутку.
    readonly property real maxHeight: anchorWindow.screen ? anchorWindow.screen.height - anchorWindow.height - 16 : 10000

    implicitWidth: panelItem.implicitWidth + Theme.quickPadding * 2
    implicitHeight: Math.min(panelItem.implicitHeight + Theme.quickPadding * 2, root.maxHeight)
    // m3 container transform: контейнер меняет размер на emphasized.
    // Во время жеста высоту ведёт палец — анимация только отставала бы.
    Behavior on implicitWidth {
        enabled: !UiState.swipeActive
        MotionNumber {
            duration: Theme.motionMedium2
            curve: Theme.curveEmphasized
        }
    }
    Behavior on implicitHeight {
        enabled: !UiState.swipeActive
        MotionNumber {
            duration: Theme.motionMedium2
            curve: Theme.curveEmphasized
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        clip: true
        radius: Theme.quickRadius
        color: Theme.quickBackground
        border.width: 1
        border.color: Theme.quickBorder

        // Появление: лёгкий рост из угла кнопки.
        // m3 enter: проявление с 92% и ростом из угла кнопки.
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : Theme.motionFadeThroughScale
        transformOrigin: Item.TopRight
        Behavior on opacity {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on scale {
            MotionNumber {
                duration: Theme.motionMedium1
                curve: Theme.curveEmphasizedDecelerate
            }
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: Theme.quickPadding
            contentWidth: width
            contentHeight: panelItem.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            QuickPanel {
                id: panelItem
                width: scroller.width
            }
        }
    }
}
