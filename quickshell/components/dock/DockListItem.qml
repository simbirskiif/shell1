import QtQuick
import Quickshell
import "../../singletons"

// Результат поиска в двух видах: строка и плитка.
//
// Сознательно без MorphShape: в сетке одновременно живут десятки
// делегатов, и Canvas-контуры на каждом заметно роняли отклик меню.
// Здесь только прямоугольники со скруглением и пружины — меню остаётся
// быстрым, а состояние читается цветом и контуром.
Item {
    id: root

    required property var item
    property bool tile: false
    required property int index

    signal activated()

    width: GridView.view ? GridView.view.cellWidth : 0
    height: GridView.view ? GridView.view.cellHeight : 44
    scale: 1
    opacity: 1

    readonly property bool current: GridView.isCurrentItem
    readonly property bool hovered: hover.containsMouse
    readonly property bool pressed: hover.pressed

    readonly property string iconSource: {
        if (!root.item || !root.item.icon)
            return "";
        return Quickshell.iconPath(root.item.icon, true);
    }

    // Один акцент: выбранный элемент — secondary-container, остальные —
    // тональная поверхность. Наведение лишь чуть поднимает тон.
    readonly property color baseColor: root.current ? Theme.secondaryContainer
                                                    : Theme.surfaceContainerHigh
    readonly property color inkColor: root.current ? Theme.scheme.onSecondaryContainer
                                                   : Theme.scheme.onSurface
    readonly property color cardColor: Theme.mix(root.baseColor, root.inkColor,
                                                 root.hovered && !root.current ? 0.05 : 0)

    function activate() {
        root.activated();
        if (root.item)
            DockSearch.activate(root.item);
    }

    Item {
        id: content
        anchors.fill: parent

        scale: root.pressed ? 0.97
             : (root.tile && root.hovered ? 1.02 : 1)
        Behavior on scale { SpringSpatialFast {} }

        // Плитка: ровный squircle-контейнер.
        Rectangle {
            id: tileCard
            visible: root.tile
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, root.width - Theme.space.xs)
            height: Math.max(0, root.height - Theme.space.xs)
            radius: Theme.shape.lg
            color: root.cardColor
            border.width: root.current ? 0 : 1
            border.color: Theme.outlineVariant
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Круглая подложка иконки в плитке.
        Rectangle {
            id: tileOrb
            visible: root.tile
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.space.sm
            width: 46
            height: 46
            radius: width / 2
            color: Theme.withAlpha(root.inkColor, 0.10)
        }

        Image {
            id: tileIcon
            visible: root.tile
            anchors.centerIn: tileOrb
            width: Theme.iconSize.lg + Theme.space.xs
            height: width
            source: root.tile ? root.iconSource : ""
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

        Text {
            anchors.centerIn: tileOrb
            visible: root.tile && tileIcon.status !== Image.Ready
            text: root.item && root.item.title
                  ? String(root.item.title).charAt(0).toUpperCase() : "?"
            color: root.inkColor
            font: Theme.typeTitleMedium
        }

        Text {
            visible: root.tile
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.space.sm
            anchors.rightMargin: Theme.space.sm
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space.sm
            text: root.item ? root.item.title : ""
            color: root.inkColor
            font: Theme.typeLabelMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Строка: пилюля на всю ширину.
        Rectangle {
            id: rowCard
            visible: !root.tile
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.width
            height: Math.max(0, root.height - Theme.space.xs)
            radius: height / 2
            color: root.cardColor
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            id: rowOrb
            visible: !root.tile
            anchors.left: parent.left
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: width / 2
            color: root.current ? Theme.tertiaryContainer : Theme.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Image {
            id: iconImage
            visible: !root.tile
            anchors.centerIn: rowOrb
            width: Theme.iconSize.lg
            height: width
            source: root.tile ? "" : root.iconSource
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

        Text {
            anchors.centerIn: rowOrb
            visible: !root.tile && iconImage.status !== Image.Ready
            text: root.item && root.item.title
                  ? String(root.item.title).charAt(0).toUpperCase() : "?"
            color: root.inkColor
            font: Theme.typeTitleMedium
        }

        Column {
            visible: !root.tile
            anchors.left: rowOrb.right
            anchors.leftMargin: Theme.space.md
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.lg
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.item ? root.item.title : ""
                color: root.inkColor
                font: root.current ? Theme.typeEmphasizedLabelLarge : Theme.typeBodyLarge
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                width: parent.width
                visible: root.item && root.item.subtitle !== ""
                text: root.item ? root.item.subtitle : ""
                color: root.current ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.8)
                                    : Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelMedium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()

        onEntered: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            if (Date.now() - DockState.pointerMovedAt > 150)
                return;
            if (GridView.view && GridView.view.currentIndex !== root.index)
                GridView.view.currentIndex = root.index;
        }

        onPositionChanged: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            if (Date.now() - DockState.pointerMovedAt > 150)
                return;
            if (GridView.view && GridView.view.currentIndex !== root.index)
                GridView.view.currentIndex = root.index;
        }

        onClicked: {
            if (GridView.view)
                GridView.view.currentIndex = root.index;
            root.activate();
            DockState.hide();
        }
    }
}
