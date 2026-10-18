import QtQuick
import "../../singletons"
import "../core"

// Контекстное меню рабочего стола. Живёт внутри того же DesktopLayer, что и
// виджеты: отдельного окна/слоя для меню нет.
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
    height: menuColumn.implicitHeight + 12
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
            items.push({ label: "Параметры виджета…", action: "widget-settings",
                         separator: false })
            items.push({ label: "", action: "", separator: true })
        }
        items.push({ label: "Добавить виджет…", action: "add", separator: false })
        items.push({ label: "Параметры виджетов…", action: "global", separator: false })
        if (root.editing) {
            items.push({ label: "", action: "", separator: true })
            items.push({ label: "Готово", action: "commit", separator: false })
            items.push({ label: "Отмена", action: "cancel", separator: false })
        } else {
            items.push({ label: "", action: "", separator: true })
            items.push({ label: "Изменить расположение", action: "edit", separator: false })
        }
        return items
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.quickRadius
        color: Theme.menuSurface
        border.width: 1
        border.color: Theme.menuBorder
        opacity: 0.98
    }

    Column {
        id: menuColumn

        anchors.fill: parent
        anchors.margins: 6
        spacing: 1

        Repeater {
            model: root.menuItems()

            delegate: Item {
                id: menuRow

                required property var modelData

                width: menuColumn.width
                height: menuRow.modelData.separator ? 9 : 32

                Rectangle {
                    anchors.fill: parent
                    visible: menuRow.modelData.separator
                    color: "transparent"

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.quickSeparator
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !menuRow.modelData.separator
                    radius: 8
                    color: menuHover.containsMouse
                           ? Theme.quickTileHover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 9
                        color: Theme.quickText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        text: menuRow.modelData.label
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
