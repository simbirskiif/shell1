import QtQuick
import Quickshell
import "../../singletons"

// Строка списка приложений. Высота постоянная: ListView анимирует
// смещение соседей через y, а не через изменение высоты.
Item {
    id: root

    required property var entry

    signal activated()

    height: 44
    width: ListView.view ? ListView.view.width : 0
    scale: 1
    opacity: 1

    readonly property string iconSource: {
        if (!root.entry || !root.entry.icon)
            return "";
        return Quickshell.iconPath(root.entry.icon, true);
    }

    function activate() {
        root.activated();
        if (root.entry)
            root.entry.execute();
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: hover.containsMouse ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
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
        text: root.entry && root.entry.name
              ? String(root.entry.name).charAt(0).toUpperCase() : "?"
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    Text {
        anchors.left: iconImage.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.entry ? root.entry.name : ""
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) DockState.keepAlive()
        onClicked: {
            root.activate();
            DockState.hide();
        }
    }
}
