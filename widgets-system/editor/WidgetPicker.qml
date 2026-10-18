pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// Каталог виджетов (раздел 8.5 ТЗ): поиск, превью, добавление тапом,
// drag-and-drop на сетку, список пользовательских путей и «Добавить папку…».
Item {
    id: root

    required property var screen
    required property var metrics

    property var filtered: []
    property string query: ""
    property string message: ""
    property bool showPathInput: false

    visible: EditorState.pickerOpen && EditorState.uiScreen === root.screen.name
    width: Math.min(360, parent.width - 24)
    height: Math.min(parent.height - 24, 700)
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    z: 120

    onVisibleChanged: {
        if (visible)
            root.refreshFilter()
        else
            PickerState.cancel()
    }

    Connections {
        target: WidgetRegistry

        function onRegistryChanged() {
            root.refreshFilter()
        }
    }

    Connections {
        target: PickerState

        function onMessageChanged() {
            root.message = PickerState.message
        }
    }

    function refreshFilter(): void {
        const source = WidgetRegistry.widgets || []
        const needle = root.query.trim().toLowerCase()
        const result = []
        for (const widget of source) {
            if (needle.length === 0
                || widget.name.toLowerCase().indexOf(needle) >= 0
                || widget.id.toLowerCase().indexOf(needle) >= 0
                || widget.description.toLowerCase().indexOf(needle) >= 0)
                result.push(widget)
        }
        root.filtered = result
    }

    function add(widget: var): void {
        const instance = LayoutStore.addWidget(root.screen.name, widget, root.metrics)
        if (!instance) {
            root.message = "Нет места для «" + widget.name + "»"
        } else {
            root.message = "Добавлен: " + widget.name
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.outline
        opacity: PickerState.active ? 0.42 : 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        opacity: PickerState.active ? 0.42 : 1

        Row {
            width: parent.width

            Text {
                width: parent.width - 30
                color: Theme.colors.onSurface
                font.pixelSize: 15
                font.bold: true
                text: "Виджеты"
            }

            HostButton {
                text: "✕"
                onClicked: EditorState.closePicker()
            }
        }

        TextInput {
            id: search

            width: parent.width
            height: 30
            padding: 6
            color: Theme.colors.onSurface
            font.pixelSize: 12
            selectionColor: Theme.colors.primary
            clip: true
            text: root.query
            onTextChanged: {
                root.query = text
                root.refreshFilter()
            }
            onAccepted: root.refreshFilter()

            Text {
                anchors.fill: parent
                anchors.leftMargin: 6
                verticalAlignment: Text.AlignVCenter
                visible: search.text.length === 0
                color: Theme.colors.onSurfaceVariant
                font.pixelSize: 12
                text: "Поиск по имени или id"
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                z: -1
                radius: 7
                color: Theme.colors.surfaceVariant
                opacity: 0.4
            }
        }

        Flickable {
            width: parent.width
            height: Math.max(120, parent.height - 250)
            clip: true
            contentHeight: cards.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: !PickerState.active

            Flow {
                id: cards

                width: parent.width
                spacing: 8

                Repeater {
                    model: root.filtered

                    delegate: WidgetPreviewCard {
                        id: card

                        required property var modelData

                        widget: modelData
                        metrics: root.metrics
                        screenName: root.screen.name

                        onAddRequested: root.add(card.widget)
                        onDragStarted: (point) => PickerState.start(card.widget,
                                                                    root.metrics,
                                                                    root.screen.name,
                                                                    point)
                        onDragMoved: (point) => PickerState.update(point)
                        onDragFinished: PickerState.finish()
                    }
                }
            }
        }

        Text {
            width: parent.width
            color: Theme.colors.onSurfaceVariant
            font.pixelSize: 11
            text: "Доступно: " + root.filtered.length
        }

        Text {
            width: parent.width
            visible: root.message.length > 0
            color: root.message.indexOf("Нет места") >= 0
                   ? Theme.colors.error : Theme.colors.onSurfaceVariant
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            text: root.message
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.colors.outline
            opacity: 0.4
        }

        Text {
            color: Theme.colors.onSurfaceVariant
            font.pixelSize: 11
            text: "Пользовательские пути"
        }

        Repeater {
            model: Config.extraPaths || []

            delegate: Text {
                required property var modelData

                width: parent.width
                color: Theme.colors.onSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideMiddle
                text: modelData
            }
        }

        HostButton {
            text: root.showPathInput ? "Скрыть ввод пути" : "Добавить папку…"
            onClicked: root.showPathInput = !root.showPathInput
        }

        Row {
            width: parent.width
            visible: root.showPathInput
            spacing: 4

            TextInput {
                id: pathInput

                width: parent.width - 82
                height: 28
                padding: 4
                color: Theme.colors.onSurface
                font.pixelSize: 11
                clip: true
                selectionColor: Theme.colors.primary

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: pathInput.text.length === 0
                    color: Theme.colors.onSurfaceVariant
                    font.pixelSize: 10
                    text: "/путь/к/папке"
                }
            }

            HostButton {
                text: "Добавить"
                onClicked: {
                    if (Config.addExtraPath(pathInput.text)) {
                        root.message = "Путь добавлен, каталог обновляется"
                        pathInput.text = ""
                    } else {
                        root.message = "Путь уже добавлен или указан неверно"
                    }
                }
            }
        }
    }
}
