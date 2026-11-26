import QtQuick
import ".."
import "../../singletons"

// Карточка устройства в панели конфиденциальности. Активная — в цвете
// устройства, неактивная — спокойная tonal-карточка. Разделители не нужны:
// состояние читается цветом, expressive-орбом и весом шрифта.
Item {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    required property color accent
    required property color onAccent
    required property color container
    required property color onContainer
    property bool active: false
    property bool available: true

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 88

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.xl
        color: root.active ? root.container : Theme.surfaceContainerHigh
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    PrivacyOrb {
        id: orb

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        accent: root.accent
        onAccent: root.onAccent
        active: root.active
        animated: false
        interactive: false
        visualSize: 48
        hitSize: 48
    }

    Column {
        anchors.left: orb.right
        anchors.leftMargin: Theme.space.md
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: root.active
                   ? root.onContainer
                   : (root.available ? Theme.scheme.onSurface : Theme.quickTextDim)
            // Активная карточка — выразительнее: другой вес и семейство.
            font: root.active ? Theme.typeEmphasizedTitleMedium : Theme.typeTitleMedium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.subtitle
            color: root.active ? root.onContainer : Theme.scheme.onSurfaceVariant
            opacity: root.active ? 0.88 : 1
            font: Theme.typeBodyMedium
            elide: Text.ElideRight
        }
    }
}
