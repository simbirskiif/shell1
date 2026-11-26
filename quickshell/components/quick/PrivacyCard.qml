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
    property bool stoppable: false

    signal stopRequested()

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

    // Действие справа. У активного устройства оно либо останавливает
    // поток, либо честно говорит, что отсюда это невозможно (V4L2/GeoClue).
    Item {
        id: action

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        visible: root.active
        width: root.active ? (root.stoppable ? 64 : 92) : 0
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: Theme.shape.full
            color: root.stoppable ? Theme.withAlpha(root.onContainer, 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: root.stoppable ? "Stop" : "Can't stop"
                color: root.onContainer
                opacity: root.stoppable ? 1 : 0.65
                font: root.stoppable ? Theme.typeLabelLarge : Theme.typeLabelSmall
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.stoppable
                hoverEnabled: root.stoppable
                cursorShape: root.stoppable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.stopRequested()
            }
        }
    }

    Column {
        anchors.left: orb.right
        anchors.leftMargin: Theme.space.md
        anchors.right: action.left
        anchors.rightMargin: root.active ? Theme.space.sm : 0
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
