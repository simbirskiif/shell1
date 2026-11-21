import QtQuick
import ".."
import "../../singletons"

// Строка текущего устройства: подпись и стрелка «открыть список».
// Нажатие открывает отдельную панель выбора устройств.
Item {
    id: root

    required property string icon
    required property string text

    signal clicked()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Theme.listItemHeight
    height: implicitHeight

    // Строка списка m3: прозрачный контейнер, hover — state layer on-surface.
    Rectangle {
        anchors.fill: parent
        color: deviceHover.containsMouse
               ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motionShort3 } }
    }

    Text {
        id: iconText
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.md
    }

    Text {
        id: label
        anchors.left: iconText.right
        anchors.leftMargin: Theme.space.md
        anchors.right: chevron.left
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        text: root.text !== "" ? root.text : "No device"
        elide: Text.ElideRight
        color: Theme.scheme.onSurface
        font: Theme.typeBodyLarge
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf054"
        color: Theme.scheme.onSurfaceVariant
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize.sm
    }

    MouseArea {
        id: deviceHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Разделитель m3: отделяет строку устройства от блока громкости выше.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.space.lg
        anchors.rightMargin: Theme.space.lg
        height: 1
        color: Theme.outlineVariant
    }
}
