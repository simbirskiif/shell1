import QtQuick
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

    Component.onCompleted: root.syncVisibility()

    // Правый верхний угол попапа — под кнопкой в баре, растёт вниз-влево.
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width - Theme.barPadding
    anchor.rect.y: anchorWindow.height + 4
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left

    color: "transparent"

    implicitWidth: panelItem.implicitWidth + Theme.quickPadding * 2
    implicitHeight: panelItem.implicitHeight + Theme.quickPadding * 2
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.quickWindowDuration
            easing.type: Theme.quickWindowEasing
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.quickWindowDuration
            easing.type: Theme.quickWindowEasing
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
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : Theme.quickIdleScale
        transformOrigin: Item.TopRight
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.quickViewDuration
                easing.type: Theme.quickViewEasing
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.quickWindowDuration
                easing.type: Theme.quickWindowEasing
            }
        }

        QuickPanel {
            id: panelItem
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.quickPadding
        }
    }
}
