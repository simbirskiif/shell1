import QtQuick
import "../core"

// Маленькая кнопка для карточек ошибок/плейсхолдеров. В этапе 5 её заменит
// общий набор элементов редактора.
Rectangle {
    id: root

    property string text: ""
    signal clicked()

    implicitWidth: label.implicitWidth + (root.text.length > 1 ? 18 : 12)
    implicitHeight: 26
    radius: 8
    color: mouse.containsMouse ? Theme.colors.primaryContainer : Theme.colors.surface
    border.width: 1
    border.color: Theme.colors.outline

    Text {
        id: label

        anchors.centerIn: parent
        color: Theme.colors.onSurface
        font.pixelSize: 11
        text: root.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
