import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Плитка быстрых настроек — спокойный Expressive: одинаковые по форме
// карточки, один акцентный контейнер для включённого состояния, круглая
// иконка-орб. Форма меняется только между squircle и pill (широкие формы,
// которые не растягиваются), состояние читается цветом и контуром.
Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    required property bool active
    property bool wifiStatus: false

    property bool editable: false
    property bool shown: true
    property int order: -1
    property int columns: 2
    property real stepX: width
    property real stepY: height

    signal toggled()
    signal expandRequested()
    signal removeRequested()
    signal reorderRequested(int from, int to)

    implicitWidth: Theme.quickWidth / 2
    implicitHeight: Theme.quickTileHeight
    color: "transparent"

    readonly property bool hovered: hover.containsMouse
    readonly property bool pressedDown: dragArea.pressed || hover.pressed
    readonly property color containerColor: root.active ? Theme.secondaryContainer
                                                       : Theme.surfaceContainerHigh
    readonly property color contentColor: root.active ? Theme.scheme.onSecondaryContainer
                                                      : Theme.scheme.onSurface

    scale: (root.editable ? 0.94 : 1) * (root.shown ? 1 : Theme.motionElementScale)
           * (root.pressedDown ? 0.96 : (root.hovered && !root.editable ? 1.02 : 1))
    Behavior on scale { SpringSpatial {} }
    Behavior on x { SpringSpatial {} }
    Behavior on y { SpringSpatial {} }
    Behavior on opacity { SpringEffects {} }

    // Фон: squircle в покое, pill у включённой. Никаких радиальных
    // контуров на широкой карточке — они превращаются в овал.
    MorphShape {
        anchors.fill: parent
        shape: root.active ? "pill" : "squircle"
        color: root.containerColor
        borderWidth: root.active ? 0 : 1
        borderColor: Theme.outlineVariant
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: !root.editable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expandRequested()
    }

    // Иконка-орб: обычный круг, у включённой — primary/on-primary.
    Rectangle {
        id: orb
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: width / 2
        color: root.active ? Theme.secondary : Theme.surfaceContainerHighest
        Behavior on color { ColorAnimation { duration: 140 } }

        MouseArea {
            anchors.fill: parent
            enabled: !root.editable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }

        Text {
            anchors.centerIn: parent
            visible: !root.wifiStatus
            text: root.icon
            color: root.active ? Theme.scheme.onSecondary : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 18
        }

        WifiStatusIcon {
            anchors.centerIn: parent
            visible: root.wifiStatus
            width: 24
            height: 24
            glyphSize: 18
            onAccent: root.active
            offMode: !NetworkService.wifiEnabled
            signal: NetworkService.connectedSignal
        }
    }

    Column {
        anchors.left: orb.right
        anchors.leftMargin: Theme.space.md
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            width: parent.width
            text: root.title
            color: root.contentColor
            font: root.active ? Theme.typeEmphasizedLabelLarge : Theme.typeLabelLarge
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.active ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.78)
                               : Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelMedium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.editable
        preventStealing: true
        cursorShape: Qt.DragMoveCursor

        onPositionChanged: mouse => {
            if (!pressed || root.order < 0)
                return;
            const baseX = (root.order % root.columns) * root.stepX;
            const baseY = Math.floor(root.order / root.columns) * root.stepY;
            const col = Math.max(0, Math.min(root.columns - 1, Math.floor((baseX + mouse.x) / root.stepX)));
            const row = Math.max(0, Math.floor((baseY + mouse.y) / root.stepY));
            const target = row * root.columns + col;
            if (target !== root.order)
                root.reorderRequested(root.order, target);
        }
    }

    Rectangle {
        id: removeButton
        visible: root.editable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        width: 28
        height: 28
        radius: width / 2
        color: removeHover.containsMouse ? Theme.error : Theme.errorContainer
        border.width: 2
        border.color: Theme.quickBackground
        z: 3

        Text {
            anchors.centerIn: parent
            text: "\uf068"
            color: removeHover.containsMouse ? Theme.scheme.onError : Theme.scheme.onErrorContainer
            font.family: Theme.iconFontFamily
            font.pixelSize: 12
        }

        MouseArea {
            id: removeHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeRequested()
        }
    }
}
