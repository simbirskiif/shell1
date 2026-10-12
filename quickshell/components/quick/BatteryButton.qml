import QtQuick
import ".."
import "../../singletons"

// Кнопка батареи для шапки основной панели: значок по уровню заряда
// и процент. Нажатие открывает панель питания.
Item {
    id: root

    required property int level
    required property bool charging

    signal clicked()

    implicitWidth: content.implicitWidth + 18
    implicitHeight: 28

    readonly property string glyph: {
        if (root.charging)
            return "\uf0e7";
        if (root.level >= 90)
            return "\uf240";
        if (root.level >= 65)
            return "\uf241";
        if (root.level >= 40)
            return "\uf242";
        if (root.level >= 15)
            return "\uf243";
        return "\uf244";
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? Theme.quickTileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.charging ? Theme.accent : Theme.quickText
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.level + "%"
            color: Theme.quickText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
