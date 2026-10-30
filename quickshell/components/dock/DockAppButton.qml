import QtQuick
import Quickshell
import ".."
import "../../singletons"

// Иконка приложения в компактной полосе дока. Размер карточки не меняется:
// увеличение при наведении — это transform, поэтому соседние иконки не едут.
Item {
    id: root

    required property var entry

    property int size: Theme.dockButtonSize
    property int iconSize: Theme.dockIconSize

    signal activated()

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property string iconSource: {
        if (!root.entry || !root.entry.icon)
            return "";
        return Quickshell.iconPath(root.entry.icon, true);
    }

    scale: hover.pressed ? 0.94 : (hover.containsMouse ? 1.12 : 1)
    Behavior on scale {
        MotionNumber {
            duration: Theme.motionShort3
            curve: Theme.curveDockExpressive
        }
    }

    transform: Translate {
        y: hover.containsMouse && !hover.pressed ? -3 : 0
        Behavior on y {
            MotionNumber {
                duration: Theme.motionShort3
                curve: Theme.curveDockExpressive
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: hover.containsMouse ? Theme.quickTileHover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.motionShort3 }
        }
    }

    // Заглушка под иконкой: у части .desktop-файлов картинки нет.
    Text {
        anchors.centerIn: parent
        visible: iconImage.status !== Image.Ready
        text: root.entry && root.entry.name
              ? String(root.entry.name).charAt(0).toUpperCase() : "?"
        color: Theme.quickText
        font.family: Theme.fontFamily
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }

    Image {
        id: iconImage
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.iconSource
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
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
