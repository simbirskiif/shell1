import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../singletons"

// Выпадающая панель быстрых настроек под кнопкой статуса в баре.
// Ширина ограничена темой, высота следует за содержимым с анимацией —
// вместе с кроссфейдом видов это даёт плавное «раскрытие» внутрь.
PopupWindow {
    id: root

    required property PanelWindow anchorWindow

    property string panel: ""

    function toggle() {
        root.visible = !root.visible;
    }

    function close() {
        root.visible = false;
    }

    onVisibleChanged: {
        if (!visible)
            panel = "";
    }

    // Правый верхний угол попапа — под кнопкой в баре, растёт вниз-влево.
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width - Theme.barPadding
    anchor.rect.y: anchorWindow.height + 4
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left

    color: "transparent"
    visible: false

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

    // Клик мимо попапа закрывает его.
    HyprlandFocusGrab {
        windows: [root.anchorWindow, root]
        active: root.visible
        onCleared: root.close()
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
            panel: root.panel
        }
    }
}
