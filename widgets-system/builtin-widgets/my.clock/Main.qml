import QtQuick
import Quickshell

// Пример: часы. Показывает использование ctx.settings, ctx.colors, ctx.dp.
Item {
    id: root

    required property var ctx

    SystemClock {
        id: clock
        precision: root.ctx.settings.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(root.ctx.dp * 2)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.ctx.colors.onSurface
            font.pixelSize: Math.max(14, Math.round(root.ctx.dp
                * (root.ctx.sizeClass === "compact" ? 26 : 42)))
            font.bold: true
            text: Qt.formatTime(clock.date,
                                root.ctx.settings.format24 ? "HH:mm" : "hh:mm AP")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.ctx.colors.onSurfaceVariant
            font.pixelSize: Math.max(10, Math.round(root.ctx.dp * 11))
            text: Qt.formatDate(clock.date, "ddd, d MMM")
        }
    }

    Component.onCompleted: console.info("[widget:my.clock] загружен v2")
}
