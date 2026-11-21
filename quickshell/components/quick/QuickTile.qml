import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Плитка быстрых настроек в духе Material 3 Expressive.
//
// Состояние читается не только цветом, но и формой: выключенная плитка —
// спокойный squircle на тональной поверхности, включённая — свой
// выразительный контур (cookie, clover, sunny, burst…) и крупный цветной
// контейнер (primary/tertiary/secondary). При нажатии плитка сжимается и
// на миг становится более круглой, при наведении — слегка раздувается.
// Кружок-иконка тоже меняет форму, поэтому «включено» видно боковым зрением.
Rectangle {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    required property bool active
    // Плитка Wi-Fi: в кружке деления сигнала вместо обычного глифа.
    property bool wifiStatus: false
    // Акцентная пара и форма включённого состояния (задаёт панель).
    property string accentTone: "secondary"
    property string expressiveShape: "cookie"

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
    // Корневой Rectangle нужен только для совместимости с раскладкой,
    // сам фон рисует MorphShape ниже.
    color: "transparent"

    readonly property bool hovered: hover.containsMouse
    readonly property bool pressedDown: dragArea.pressed || hover.pressed

    readonly property color activeContainer: {
        if (root.accentTone === "primary")
            return Theme.primaryContainer;
        if (root.accentTone === "tertiary")
            return Theme.tertiaryContainer;
        if (root.accentTone === "neutral")
            return Theme.surfaceContainerHighest;
        return Theme.secondaryContainer;
    }

    readonly property color activeInk: {
        if (root.accentTone === "primary")
            return Theme.scheme.onPrimaryContainer;
        if (root.accentTone === "tertiary")
            return Theme.scheme.onTertiaryContainer;
        if (root.accentTone === "neutral")
            return Theme.scheme.onSurface;
        return Theme.scheme.onSecondaryContainer;
    }

    readonly property color containerColor: root.active ? root.activeContainer
                                                       : Theme.surfaceContainerHigh
    readonly property color contentColor: root.active ? root.activeInk : Theme.scheme.onSurface

    // В редакторе плитка выглядит меньше, но место занимает то же.
    scale: (root.editable ? 0.92 : 1) * (root.shown ? 1 : Theme.motionElementScale)
           * (root.pressedDown ? 0.93 : (root.hovered && !root.editable ? 1.03 : 1))

    Behavior on scale { SpringSpatial {} }
    Behavior on x { SpringSpatial {} }
    Behavior on y { SpringSpatial {} }
    Behavior on opacity { SpringEffects {} }

    // Фон: морфящаяся форма. Выключенная — squircle, включённая — свой
    // контур; нажатие на миг возвращает к squircle и обратно.
    MorphShape {
        anchors.fill: parent
        shape: root.pressedDown ? "squircle"
             : root.active ? root.expressiveShape
             : "squircle"
        color: root.containerColor
        modulation: 0.5
        // Тонкий контур только у выключенной плитки: активная держится
        // цветом, а не обводкой.
        borderWidth: root.active ? 0 : 1
        borderColor: Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: !root.editable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expandRequested()
    }

    // Круг-иконка: выключенная — круг, включённая — «солнышко».
    MorphShape {
        id: circle
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        shape: root.active
               ? (root.expressiveShape === "sunny" || root.expressiveShape === "burst"
                  || root.expressiveShape === "clover" || root.expressiveShape === "blob"
                  ? root.expressiveShape : "sunny")
               : "circle"
        color: root.active ? root.activeInk : Theme.surfaceContainerHighest

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
            color: root.active ? root.activeContainer : Theme.scheme.onSurfaceVariant
            font.family: Theme.iconFontFamily
            font.pixelSize: 20
        }

        WifiStatusIcon {
            anchors.centerIn: parent
            visible: root.wifiStatus
            width: 26
            height: 26
            glyphSize: 20
            onAccent: root.active
            offMode: !NetworkService.wifiEnabled
            signal: NetworkService.connectedSignal
        }
    }

    Column {
        id: texts
        anchors.left: circle.right
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
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.active ? Theme.withAlpha(root.activeInk, 0.78)
                               : Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelMedium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // Перетаскивание в редакторе: меняем порядок, когда курсор уходит
    // в другую ячейку сетки.
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

    // «Минус» в правом верхнем углу — убрать плитку в доступные.
    Item {
        id: removeButton
        visible: root.editable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        width: 32
        height: 32
        z: 3

        MorphShape {
            anchors.fill: parent
            shape: removeHover.containsMouse ? "burst" : "circle"
            color: removeHover.containsMouse ? Theme.error : Theme.errorContainer
        }

        Text {
            anchors.centerIn: parent
            text: "\uf068"
            color: removeHover.containsMouse ? Theme.scheme.onError : Theme.scheme.onErrorContainer
            font.family: Theme.iconFontFamily
            font.pixelSize: 13
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
