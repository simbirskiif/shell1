import QtQuick
import ".."
import "../expressive"
import "../../singletons"

// Колокольчик в баре. Есть непрочитанные — кнопка становится «печеньем»
// на secondary-container; нет — прозрачный круг. Форма и цвет меняются
// вместе, поэтому состояние видно до чтения цифры.
Item {
    id: root

    property bool opened: false

    signal clicked()

    implicitWidth: 40
    implicitHeight: 40

    readonly property bool hovered: hover.containsMouse
    readonly property bool unread: NotificationService.hasUnread

    scale: hover.pressed ? 0.92 : (root.hovered ? 1.06 : 1)
    Behavior on scale { SpringSpatialFast {} }

    MorphShape {
        anchors.fill: parent
        shape: root.unread ? "cookie" : "circle"
        modulation: 0.75
        color: root.unread ? Theme.secondaryContainer
             : root.hovered ? Theme.surfaceContainerHighest
             : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: "\uf0f3"
        color: root.unread ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
        font.family: Theme.iconFontFamily
        font.pixelSize: 18
    }

    // Точка непрочитанного.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.top: parent.top
        anchors.topMargin: 2
        width: 9
        height: 9
        radius: width / 2
        visible: root.unread
        color: Theme.error
        border.width: 1.5
        border.color: Theme.barBackground
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
