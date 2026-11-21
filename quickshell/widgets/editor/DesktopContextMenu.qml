pragma ComponentBehavior: Bound

import QtQuick
import "../../components/expressive"
import "../../singletons"
import "../core"

// Контекстное меню рабочего стола. Живёт внутри того же DesktopLayer, что и
// виджеты: отдельного окна/слоя для меню нет.
//
// Expressive: крупная squircle-поверхность, строки-пилюли 48 px с морфящейся
// формой на hover/press. Тонких разделителей нет — пункты сгруппированы
// цветом: настройки — tertiary-контейнер, «Готово/Изменить» — primary,
// «Отмена» — error-контейнер. Тень не нужна: глубину задаёт тон поверхности.
Item {
    id: root

    property bool opened: false
    property point position: Qt.point(0, 0)
    property string screenName: ""
    property string targetUid: ""
    property bool editing: EditorState.active

    signal action(string name)

    visible: root.opened
    width: 252
    height: menuColumn.implicitHeight + Theme.space.sm * 2
    x: Math.max(12, Math.min(root.position.x, parent.width - root.width - 12))
    y: Math.max(12, Math.min(root.position.y, parent.height - root.height - 12))
    z: 210

    // Появление — пружина масштаба из точки клика.
    scale: root.opened ? 1 : 0.9
    transformOrigin: Item.TopLeft
    Behavior on scale { SpringSpatial {} }

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

    // Крупная M3-поверхность меню: большой радиус и тональный слой, без
    // обводки. Пункты внутри — отдельные morph-пилюли.
    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.xlIncreased
        color: Theme.veil(Theme.surfaceContainer, 0.98)
    }

    Column {
        id: menuColumn

        anchors.fill: parent
        anchors.margins: Theme.space.sm
        spacing: 2

        Repeater {
            model: root.menuItems()

            delegate: Item {
                id: menuRow

                required property var modelData

                readonly property string actionName: menuRow.modelData.action
                readonly property bool separator: menuRow.modelData.separator

                // Группировка цветом вместо разделителей: каждый класс
                // действий получает свой контейнер.
                readonly property bool settingsGroup: actionName === "widget-settings"
                                                      || actionName === "add"
                                                      || actionName === "global"
                readonly property bool commitGroup: actionName === "commit"
                                                    || actionName === "edit"
                readonly property bool dangerGroup: actionName === "cancel"

                width: menuColumn.width
                // Пустой «разделитель» — только воздух, без линии.
                height: menuRow.separator ? Theme.space.xs : 48

                MorphShape {
                    anchors.fill: parent
                    visible: !menuRow.separator
                    shape: menuHover.pressed ? "squircle"
                         : menuRow.commitGroup ? "pill"
                         : menuRow.hovered ? "pill"
                         : "cookie"
                    modulation: menuRow.commitGroup ? 0.35 : 0.45
                    color: menuRow.commitGroup
                           ? (menuHover.containsMouse
                              ? Theme.mix(Theme.primaryContainer,
                                          Theme.scheme.onPrimaryContainer, Theme.stateHover)
                              : Theme.primaryContainer)
                           : menuRow.dangerGroup
                             ? (menuHover.containsMouse
                                ? Theme.mix(Theme.errorContainer,
                                            Theme.scheme.onErrorContainer, Theme.stateHover)
                                : Theme.errorContainer)
                             : menuRow.hovered
                               ? Theme.tertiaryContainer
                               : "transparent"
                    borderWidth: 0
                }

                readonly property bool hovered: menuHover.containsMouse

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space.md
                    anchors.rightMargin: Theme.space.md
                    color: menuRow.commitGroup ? Theme.scheme.onPrimaryContainer
                         : menuRow.dangerGroup ? Theme.scheme.onErrorContainer
                         : menuRow.hovered ? Theme.scheme.onTertiaryContainer
                         : Theme.scheme.onSurface
                    font: menuRow.commitGroup || menuRow.dangerGroup
                          || menuRow.hovered ? Theme.typeEmphasizedLabelLarge
                                             : Theme.typeLabelLarge
                    elide: Text.ElideRight
                    text: menuRow.modelData.label
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                MouseArea {
                    id: menuHover

                    anchors.fill: parent
                    enabled: !menuRow.separator
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.opened = false
                        root.action(menuRow.modelData.action)
                    }
                }
            }
        }
    }
}
