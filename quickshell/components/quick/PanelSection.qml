import QtQuick
import "../expressive"
import "../../singletons"

// Заголовок секции внутри панели (m3 list section header).
Item {
    id: root

    required property string text

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 36
    height: implicitHeight

    // Маленькая выразительная точка перед заголовком: секция читается
    // как цветной маркер, а не как строка мелкого текста.
    MorphShape {
        id: dot
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        shape: "cookie"
        color: Theme.tertiary
    }

    Text {
        anchors.left: dot.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.tertiary
        font: Theme.typeEmphasizedLabelLarge
        elide: Text.ElideRight
    }
}
