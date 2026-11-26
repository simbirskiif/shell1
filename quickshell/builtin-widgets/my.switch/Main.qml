import QtQuick
import "../../singletons"

// Пример-переключатель: показывает ctx.settings и ctx.setSetting.
Item {
    id: root

    required property var ctx

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        color: root.ctx.colors.onSurfaceVariant
        font.family: root.ctx.fontFamily
        font.pixelSize: Math.max(9, Math.round(root.ctx.dp * 10))
        text: root.ctx.settings.enabled ? I18n.tr("widget.switch.on")
                                       : I18n.tr("widget.switch.off")
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, root.ctx.cell * 0.72)
        height: Math.round(width * 0.46)
        radius: height / 2
        color: root.ctx.settings.enabled
               ? root.ctx.colors.primary
               : root.ctx.colors.surfaceVariant

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.ctx.settings.enabled ? parent.width - width - 3 : 3
            color: root.ctx.settings.enabled
                   ? root.ctx.colors.onPrimary
                   : root.ctx.colors.onSurfaceVariant

            Behavior on x {
                NumberAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.ctx.setSetting("enabled", !root.ctx.settings.enabled)
    }
}
