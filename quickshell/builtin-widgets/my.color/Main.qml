import QtQuick
import "../../singletons"

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
        font.pixelSize: Math.max(10, Math.round(root.ctx.dp * 12))
        text: I18n.tr("widget.color")
    }
}
