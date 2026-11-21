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
            font.family: root.ctx.fontFamily
            font.pixelSize: Math.max(15, Math.round(root.ctx.dp
                * (root.ctx.sizeClass === "compact" ? 28 : 46)))
            font.weight: 780
            font.letterSpacing: -0.5
            text: Qt.formatTime(clock.date,
                                root.ctx.settings.format24 ? "HH:mm" : "hh:mm AP")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.ctx.colors.onSurfaceVariant
            font.family: root.ctx.fontFamily
            font.pixelSize: Math.max(10, Math.round(root.ctx.dp * 11))
            font.weight: 620
            font.letterSpacing: 0.4
            text: Qt.formatDate(clock.date, "ddd, d MMM")
        }
    }

    Component.onCompleted: console.info("[widget:my.clock] загружен v2")
}
