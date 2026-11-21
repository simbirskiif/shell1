import QtQuick

// Пример: статичный цветной блок без настроек и без ресайза (min == max).
Item {
    id: root

    required property var ctx

    Rectangle {
        anchors.fill: parent
        radius: Math.round(root.ctx.cell * 0.16)
        color: root.ctx.colors.primaryContainer
    }

    Text {
        anchors.centerIn: parent
        color: root.ctx.colors.onPrimaryContainer
        font.family: root.ctx.fontFamily
        font.pixelSize: Math.max(11, Math.round(root.ctx.dp * 13))
        font.weight: 720
        font.letterSpacing: 0.2
        text: "Цвет"
    }
}
