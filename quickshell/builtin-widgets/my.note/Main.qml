import QtQuick

// Пример: заметка. Показывает строковую и enum-настройку и кликабельность
// внутри маски ввода.
Item {
    id: root

    required property var ctx

    Rectangle {
        anchors.fill: parent
        radius: Math.round(root.ctx.cell * 0.16)
        color: root.ctx.settings.accent
               ? root.ctx.colors.primaryContainer
               : root.ctx.colors.surfaceVariant
        opacity: 0.75
    }

    Text {
        anchors.fill: parent
        anchors.margins: Math.round(root.ctx.dp * 6)
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: root.ctx.settings.align === "center"
                             ? Text.AlignHCenter : Text.AlignLeft
        color: root.ctx.settings.accent
               ? root.ctx.colors.onPrimaryContainer
               : root.ctx.colors.onSurfaceVariant
        font.family: root.ctx.fontFamily
        font.pixelSize: Math.max(11, Math.round(root.ctx.dp * 13))
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        text: root.ctx.settings.text
    }

    MouseArea {
        anchors.fill: parent
        onClicked: console.info("[widget:my.note] клик по виджету")
    }
}
