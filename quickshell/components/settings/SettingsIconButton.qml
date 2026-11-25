import QtQuick
import "../../singletons"

// Круглая кнопка-иконка 40 для строк настроек (стрелки порядка, удаление).
Item {
    id: root

    required property string icon

    property bool enabled: true
    property bool accented: false

    signal clicked()

    implicitWidth: Theme.iconButtonSize
    implicitHeight: Theme.iconButtonSize
    width: implicitWidth
    height: implicitHeight
    opacity: root.enabled ? 1 : Theme.disabledContent

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.full
        color: root.accented ? Theme.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.full
        color: Theme.stateLayer(root.accented ? Theme.scheme.onSecondaryContainer
                                              : Theme.scheme.onSurface,
                                Theme.stateHover)
        opacity: hover.containsMouse && root.enabled ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionShort3 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.accented ? Theme.scheme.onSecondaryContainer
                             : Theme.scheme.onSurface
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
