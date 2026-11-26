import QtQuick
import "../../singletons"

// Строка панели конфиденциальности: значок в круге, название и состояние.
// Активная строка подсвечена цветом и точкой справа — то же состояние,
// что у значка в баре.
Item {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    property bool active: false
    property bool available: true

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 72

    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: width / 2
        color: root.active
               ? Theme.primaryContainer
               : Theme.withAlpha(Theme.scheme.onSurface, 0.06)
        Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.active
                   ? Theme.scheme.onPrimaryContainer
                   : (root.available ? Theme.scheme.onSurfaceVariant : Theme.quickTextDim)
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize.md
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Theme.space.md
        anchors.right: statusDot.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: root.available ? Theme.scheme.onSurface : Theme.quickTextDim
            font: Theme.typeBodyLarge
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.subtitle
            color: root.active ? Theme.primary : Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.motionShort4 } }
        }
    }

    // Точка «сейчас используется»: видна и без чтения подписи.
    Rectangle {
        id: statusDot

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        visible: root.active
        width: 10
        height: 10
        radius: width / 2
        color: Theme.primary
    }
}
