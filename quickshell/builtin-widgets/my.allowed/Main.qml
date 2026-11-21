import QtQuick

// Пример: виджет с size.allowed. Показывает текущий размер в клетках;
// на этапе 5 редактор будет привязывать ресайз только к этим размерам.
Item {
    id: root

    required property var ctx

    Text {
        anchors.centerIn: parent
        color: root.ctx.colors.onSurface
        font.family: root.ctx.fontFamily
        font.pixelSize: Math.max(11, Math.round(root.ctx.dp * 14))
        text: root.ctx.cols + " × " + root.ctx.rows
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        color: root.ctx.colors.onSurfaceVariant
        font.family: root.ctx.fontFamily
        font.pixelSize: Math.max(9, Math.round(root.ctx.dp * 10))
        text: "allowed"
    }
}
