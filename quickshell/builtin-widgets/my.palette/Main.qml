import QtQuick

// Пример: палитра приходит от системы (accent/neutral). Виджет не объявляет
// свою палитру; если бы она была нужна, он мог бы игнорировать ctx.colors и
// рисовать собственные цвета.
Item {
    id: root

    required property var ctx

    Column {
        anchors.centerIn: parent
        spacing: Math.round(root.ctx.dp * 4)

        Row {
            spacing: Math.round(root.ctx.dp * 4)

            Repeater {
                model: [root.ctx.colors.primary,
                        root.ctx.colors.secondary,
                        root.ctx.colors.tertiary]

                Rectangle {
                    required property var modelData

                    width: Math.round(root.ctx.cell * 0.38)
                    height: width
                    radius: width / 2
                    color: modelData
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.ctx.colors.onSurface
            font.family: root.ctx.fontFamily
            font.pixelSize: Math.max(9, Math.round(root.ctx.dp * 10))
            text: root.ctx.colorMode
        }
    }
}
