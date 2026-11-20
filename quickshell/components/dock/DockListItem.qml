import QtQuick
import Quickshell
import "../../singletons"

// Результат поиска в двух видах: строка (иконка слева, текст справа)
// и плитка (иконка сверху, подпись снизу). Высота задаётся GridView,
// поэтому переходы add/remove/displaced работают в обоих видах.
// Мышь выбирает элемент только при реальном входе/движении указателя.
Item {
    id: root

    required property var item
    property bool tile: false

    signal activated()

    width: GridView.view ? GridView.view.cellWidth : 0
    height: GridView.view ? GridView.view.cellHeight : 44
    scale: 1
    opacity: 1

    // Текущий элемент списка: в плитках он получает secondaryContainer-
    // карточку, в строках — подсветку GridView и тон on-secondary-container.
    readonly property bool current: GridView.isCurrentItem

    readonly property string iconSource: {
        if (!root.item || !root.item.icon)
            return "";
        return Quickshell.iconPath(root.item.icon, true);
    }

    function activate() {
        root.activated();
        if (root.item)
            DockSearch.activate(root.item);
    }

    // Карточка плитки M3: surfaceContainerHigh, у выбранной —
    // secondaryContainer, радиус shape.lg. Строки списка карточки не имеют:
    // их выбор подсвечивает GridView.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.tile ? Math.max(0, root.width - Theme.space.xs) : root.width
        height: root.tile ? Math.max(0, root.height - Theme.space.xs) : root.height
        radius: Theme.shape.lg
        color: root.tile ? (root.current ? Theme.secondaryContainer
                                         : Theme.surfaceContainerHigh)
                         : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    // Слой состояния M3: наведение поверх карточки/подсветки выбора.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.tile ? Math.max(0, root.width - Theme.space.xs) : root.width
        height: root.tile ? Math.max(0, root.height - Theme.space.xs) : root.height
        radius: Theme.shape.lg
        color: Theme.stateLayer(root.current ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface,
                                hover.pressed ? Theme.statePressed : Theme.stateHover)
        opacity: hover.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    // --- строковый вид ----------------------------------------------------
    Image {
        id: iconImage
        visible: !root.tile
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(Theme.iconSize.md, Math.min(Theme.iconSize.lg, DockSettings.iconSize))
        height: width
        source: root.iconSource
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    Text {
        anchors.centerIn: iconImage
        visible: !root.tile && iconImage.status !== Image.Ready
        text: root.item && root.item.title
              ? String(root.item.title).charAt(0).toUpperCase() : "?"
        color: root.current ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
        font: Theme.typeTitleMedium
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Column {
        visible: !root.tile
        anchors.left: iconImage.right
        anchors.leftMargin: Theme.space.md
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            width: parent.width
            text: root.item ? root.item.title : ""
            color: root.current ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            font: Theme.typeBodyLarge
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            width: parent.width
            visible: root.item && root.item.subtitle !== ""
            text: root.item ? root.item.subtitle : ""
            color: root.current ? Theme.withAlpha(Theme.scheme.onSecondaryContainer, 0.8)
                                : Theme.scheme.onSurfaceVariant
            font: Theme.typeBodyMedium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }
    }

    // --- плиточный вид ----------------------------------------------------
    Column {
        visible: root.tile
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Theme.space.sm)
        spacing: Theme.space.xs

        Item {
            width: Math.max(34, Math.min(46, DockSettings.iconSize + 12))
            height: width
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: tileIcon
                anchors.fill: parent
                source: root.iconSource
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: tileIcon.status !== Image.Ready
                text: root.item && root.item.title
                      ? String(root.item.title).charAt(0).toUpperCase() : "?"
                color: root.current ? Theme.scheme.onSecondaryContainer
                                    : Theme.scheme.onSurface
                font: Theme.typeTitleMedium
                Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
            }
        }

        Text {
            width: parent.width
            text: root.item ? root.item.title : ""
            color: root.current ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            font: Theme.typeLabelMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()

        // Мышь — второй приоритет: наведение меняет выделение только
        // после реального появления курсора на элементе. Неподвижный
        // указатель, под которым появилась панель, ничего не выбирает.
        onEntered: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            // Курсор не двигался — значит под ним просто переехал список.
            if (Date.now() - DockState.pointerMovedAt > 150)
                return;
            if (GridView.view && GridView.view.currentIndex !== index)
                GridView.view.currentIndex = index;
        }

        onPositionChanged: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            // Тот же фильтр, что и на входе: позиция могла измениться
            // потому, что под неподвижным курсором переехал список.
            if (Date.now() - DockState.pointerMovedAt > 150)
                return;
            if (GridView.view && GridView.view.currentIndex !== index)
                GridView.view.currentIndex = index;
        }

        onClicked: {
            if (GridView.view)
                GridView.view.currentIndex = index;
            root.activate();
            DockState.hide();
        }
    }
}
