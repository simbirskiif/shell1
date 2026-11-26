import QtQuick
import "../../singletons"
import "../core"

// Контекстное меню рабочего стола. Живёт внутри того же DesktopLayer, что и
// виджеты: отдельного окна/слоя для меню нет.
//
// Оформление — M3 menu: тональная поверхность surface-container, радиус md,
// строки 44 px, hover — state layer, разделители outline-variant. Тени не
// используются: глубину задаёт тон поверхности.
Item {
    id: root

    property bool opened: false
    property point position: Qt.point(0, 0)
    property string screenName: ""
    property string targetUid: ""
    property bool editing: EditorState.active

    signal action(string name)

    visible: root.opened
    width: 240
    height: menuColumn.implicitHeight + Theme.space.sm * 2
    x: Math.max(12, Math.min(root.position.x, parent.width - root.width - 12))
    y: Math.max(12, Math.min(root.position.y, parent.height - root.height - 12))
    z: 210

    function openAt(px: real, py: real): void {
        root.position = Qt.point(px, py)
        root.opened = true
    }

    function close(): void {
        root.opened = false
    }

    function menuItems(): var {
        const items = []
        if (root.targetUid.length > 0) {
            items.push({ labelKey: "widgets.menu.widgetSettings", action: "widget-settings",
                         separator: false })
            items.push({ labelKey: "", action: "", separator: true })
        }
        items.push({ labelKey: "widgets.menu.add", action: "add", separator: false })
        items.push({ labelKey: "widgets.menu.global", action: "global", separator: false })
        if (root.editing) {
            items.push({ labelKey: "", action: "", separator: true })
            items.push({ labelKey: "common.done", action: "commit", separator: false })
            items.push({ labelKey: "common.cancel", action: "cancel", separator: false })
        } else {
            items.push({ labelKey: "", action: "", separator: true })
            items.push({ labelKey: "widgets.menu.edit", action: "edit", separator: false })
        }
        return items
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.md
        // M3 menu — surface-container; поверх обоев оставляем лёгкую вуаль,
        // но цвет роли не подменяем.
        color: Theme.veil(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.outlineVariant
    }

    Column {
        id: menuColumn

        anchors.fill: parent
        anchors.margins: Theme.space.sm
        spacing: 0

        Repeater {
            model: root.menuItems()

            delegate: Item {
                id: menuRow

                required property var modelData

                width: menuColumn.width
                height: menuRow.modelData.separator ? Theme.space.sm + 1 : Theme.touchTarget

                Rectangle {
                    anchors.fill: parent
                    visible: menuRow.modelData.separator
                    color: "transparent"

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.space.md
                        anchors.rightMargin: Theme.space.md
                        height: 1
                        color: Theme.outlineVariant
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !menuRow.modelData.separator
                    // Строка меню — скруглённый state layer, как в M3.
                    radius: Theme.shape.xs
                    color: menuHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.space.md
                        anchors.rightMargin: Theme.space.md
                        color: Theme.scheme.onSurface
                        font: Theme.typeLabelLarge
                        elide: Text.ElideRight
                        text: menuRow.modelData.labelKey !== ""
                              ? I18n.tr(menuRow.modelData.labelKey) : ""
                    }

                    MouseArea {
                        id: menuHover

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.opened = false
                            root.action(menuRow.modelData.action)
                        }
                    }
                }
            }
        }
    }
}
