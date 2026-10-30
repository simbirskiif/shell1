import QtQuick
import Quickshell
import "../../singletons"

// Строка списка результатов. Высота постоянная: ListView анимирует
// смещение соседей через y, а не через изменение высоты.
// Мышь выбирает строку только при реальном движении указателя: если она
// просто стоит над списком, подсветка с клавиатуры не перебивается.
Item {
    id: root

    required property var item

    signal activated()

    height: 44
    width: ListView.view ? ListView.view.width : 0
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

    Image {
        id: iconImage
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
        visible: iconImage.status !== Image.Ready
        text: root.item && root.item.title
              ? String(root.item.title).charAt(0).toUpperCase() : "?"
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    Column {
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

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()

        // Мышь — второй приоритет: наведение меняет выделение только
        // после реального появления курсора на строке. Неподвижный
        // указатель, под которым появилась панель, ничего не выбирает.
        onEntered: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            if (ListView.view && ListView.view.currentIndex !== index)
                ListView.view.currentIndex = index;
        }

        // Движение внутри уже выбранной строки тоже обновляет выбор
        // (на случай, если панель появилась под неподвижным курсором).
        onPositionChanged: {
            if (Date.now() < DockState.mouseGuardUntil)
                return;
            if (ListView.view && ListView.view.currentIndex !== index)
                ListView.view.currentIndex = index;
        }

        onClicked: {
            if (ListView.view)
                ListView.view.currentIndex = index;
            root.activate();
            DockState.hide();
        }
    }
}
