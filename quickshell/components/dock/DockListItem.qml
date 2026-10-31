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

    // --- строковый вид ----------------------------------------------------
    Image {
        id: iconImage
        visible: !root.tile
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(20, Math.min(30, DockSettings.iconSize))
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
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    Column {
        visible: !root.tile
        anchors.left: iconImage.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.item ? root.item.title : ""
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.item && root.item.subtitle !== ""
            text: root.item ? root.item.subtitle : ""
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    // --- плиточный вид ----------------------------------------------------
    Column {
        visible: root.tile
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 8)
        spacing: 4

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
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Text {
            width: parent.width
            text: root.item ? root.item.title : ""
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
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
            if (GridView.view && GridView.view.currentIndex !== index)
                GridView.view.currentIndex = index;
        }

        onPositionChanged: {
            if (Date.now() < DockState.mouseGuardUntil)
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
