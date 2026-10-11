import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../singletons"

// Выпадающая панель быстрых настроек под кнопкой статуса в баре.
// Высота и ширина окна следуют за содержимым с анимацией —
// именно это даёт плавное «раскрытие» при переходе во внутреннюю панель.
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
            duration: Theme.quickAnimDuration
            easing.type: Theme.quickAnimEasing
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.quickAnimDuration
            easing.type: Theme.quickAnimEasing
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
        scale: root.visible ? 1 : 0.97
        transformOrigin: Item.TopRight
        Behavior on opacity {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.quickAnimDuration
                easing.type: Theme.quickAnimEasing
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
