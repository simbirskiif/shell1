import QtQuick
import "../../singletons"

// Компактная полоса дока: приложения, разделитель и кнопка раскрытия.
// Кнопка может стоять справа или слева. Позиции считаем вручную, чтобы
// смена стороны не пересоздавала делегаты и не мигала иконками.
Item {
    id: root

    property bool buttonFirst: false
    property real buttonSize: Theme.dockButtonSize
    property real iconSize: Theme.dockIconSize
    property real glyphSize: Theme.iconSize.sm

    signal expandRequested()

    implicitWidth: appsRow.implicitWidth + 1 + root.buttonSize
                   + Theme.dockSpacing * 2
    implicitHeight: root.buttonSize

    Row {
        id: appsRow
        x: root.buttonFirst ? root.buttonSize + Theme.dockSpacing * 2 + 1 : 0
        spacing: Theme.dockSpacing

        Repeater {
            model: DockApps.favorites

            delegate: DockAppButton {
                required property var modelData

                size: root.buttonSize
                iconSize: root.iconSize
                entry: modelData
                onActivated: DockState.hide()
            }
        }
    }

    // Разделитель между приложениями и управляющей кнопкой. M3: декоративная
    // граница — outline-variant, а не произвольный цвет.
    Item {
        id: separator
        x: root.buttonFirst ? root.buttonSize + Theme.dockSpacing
                            : appsRow.width + Theme.dockSpacing
        width: 1
        height: root.buttonSize

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: Math.round(root.buttonSize * 0.6)
            color: Theme.outlineVariant
        }
    }

    DockIconButton {
        id: expandButton
        x: root.buttonFirst ? 0 : appsRow.width + Theme.dockSpacing * 2 + 1
        size: root.buttonSize
        glyphSize: root.glyphSize
        icon: "\uf077"
        accented: true

        onClicked: root.expandRequested()
    }
}
