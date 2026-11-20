import QtQuick
import "../../singletons"

// Маленькая кнопка для карточек, каталога и попапа настроек.
// M3-кнопка-пилюля: основной вариант — filled (primary), обычный —
// тональная поверхность со state layer; кнопка висит над обоями,
// поэтому подложка непрозрачная (menuSurface, 99.5%).
Rectangle {
    id: root

    property string text: ""
    property bool active: false
    property bool prominent: false
    signal clicked()

    implicitWidth: label.implicitWidth + (root.prominent ? Theme.space.xl
                                       : (root.text.length > 1 ? Theme.space.lg : Theme.space.md))
    implicitHeight: root.prominent ? 32 : 28
    radius: Theme.shape.full
    color: root.prominent ? (mouse.containsMouse
                                ? Theme.mix(Theme.primary, Theme.scheme.onPrimary, Theme.stateHover)
                                : Theme.primary)
         : root.active ? (mouse.containsMouse ? Theme.surfaceContainerHighest
                                              : Theme.secondaryContainer)
         : (mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.menuSurface)
    border.width: root.prominent ? 0 : 1
    border.color: root.active ? Theme.primary : Theme.outlineVariant
    Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }

    Text {
        id: label

        anchors.centerIn: parent
        color: root.prominent ? Theme.scheme.onPrimary
             : root.active ? Theme.scheme.onSecondaryContainer
             : Theme.scheme.onSurface
        font: Theme.typeLabelMedium
        text: root.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
