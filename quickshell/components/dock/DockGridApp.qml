import QtQuick
import Quickshell
import "../../singletons"

// Приложение в раскрытой панели: иконка и подпись. Сетка живёт в
// DockPanel, здесь только один элемент.
Item {
    id: root

    required property var entry

    signal activated()

    readonly property string iconSource: {
        if (!root.entry || !root.entry.icon)
            return "";
        return Quickshell.iconPath(root.entry.icon, true);
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: hover.containsMouse ? Theme.quickTileHover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.motionShort3 }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 7

        Item {
            width: 42
            height: 42
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                visible: iconImage.status !== Image.Ready
                text: root.entry && root.entry.name
                      ? String(root.entry.name).charAt(0).toUpperCase() : "?"
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Image {
                id: iconImage
                anchors.fill: parent
                source: root.iconSource
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }
        }

        Text {
            width: parent.width
            text: root.entry ? root.entry.name : ""
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
        onClicked: {
            DockState.keepAlive();
            root.activated();
            if (root.entry)
                root.entry.execute();
        }
    }
}
