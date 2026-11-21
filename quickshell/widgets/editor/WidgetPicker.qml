pragma ComponentBehavior: Bound

import QtQuick
import "../../singletons"
import "../core"

// Каталог виджетов (раздел 8.5 ТЗ): поиск, превью, добавление тапом,
// drag-and-drop на сетку, список пользовательских путей и «Добавить папку…».
//
// Оформление — M3 side sheet: surface-container-low, шапка top app bar
// (titleLarge + иконка 40), поиск — filled-поле, действия — пилюли 40 px.
Item {
    id: root

    required property var screen
    required property var metrics

    property var filtered: []
    property string query: ""
    property string message: ""
    property bool showPathInput: false
    property bool hiding: false
    property real slideOffset: 0

    opacity: root.hiding ? 0 : (PickerState.active ? 0.34 : 1)
    transform: Translate { x: root.slideOffset }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.motionShort4
            easing.bezierCurve: Theme.curveStandard
        }
    }
    Behavior on slideOffset {
        NumberAnimation {
            duration: Theme.motionShort4
            easing.bezierCurve: Theme.curveStandard
        }
    }

    Timer {
        id: closeTimer
        interval: 190
        repeat: false
        onTriggered: {
            EditorState.closePicker()
            root.hiding = false
            root.slideOffset = 0
            root.message = ""
        }
    }

    function dismiss(): void {
        if (root.hiding)
            return
        root.hiding = true
        root.slideOffset = 48
        closeTimer.restart()
    }

    visible: EditorState.pickerOpen && root.screen !== null
             && EditorState.uiScreen === root.screen.name
    width: Math.min(Theme.quickWidth, parent.width)
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    z: 120

    onVisibleChanged: {
        if (visible) {
            root.hiding = false
            root.slideOffset = 0
            root.refreshFilter()
        } else {
            PickerState.cancel()
        }
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
            root.dismiss()
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: Theme.shape.xl
        bottomLeftRadius: Theme.shape.xl
        topRightRadius: 0
        bottomRightRadius: 0
        color: Theme.panelSurface
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.space.lg
        spacing: Theme.space.sm

        // Шапка — M3 top app bar: заголовок titleLarge и иконка 40.
        Item {
            width: parent.width
            height: Theme.appBarHeight

            Text {
                anchors.left: parent.left
                anchors.right: headerClose.left
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.scheme.onSurface
                font: Theme.typeTitleLarge
                elide: Text.ElideRight
                text: "Виджеты"
            }

            Item {
                id: headerClose

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: headerCloseHover.containsMouse
                           ? Theme.stateLayer(Theme.scheme.onSurface, Theme.stateHover)
                           : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: Theme.motionShort3 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: Theme.scheme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize.lg
                }

                MouseArea {
                    id: headerCloseHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss()
                }
            }
        }

        // Поиск — M3 filled-поле: surface-container-highest, radius xs,
        // обводка outline (в фокусе — primary).
        Item {
            width: parent.width
            height: 48

            Rectangle {
                anchors.fill: parent
                radius: Theme.shape.xs
                color: Theme.surfaceContainerHighest
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Theme.primary : Theme.outline
                Behavior on border.color {
                    ColorAnimation { duration: Theme.motionShort3 }
                }
            }

            TextInput {
                id: search

                anchors.fill: parent
                leftPadding: Theme.space.md
                rightPadding: Theme.space.md
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.scheme.onSurface
                font: Theme.typeBodyMedium
                selectionColor: Theme.primary
                selectedTextColor: Theme.scheme.onPrimary
                clip: true
                text: root.query
                onTextChanged: {
                    root.query = text
                    root.refreshFilter()
                }
                onAccepted: root.refreshFilter()

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.md
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text.length === 0
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyMedium
                    text: "Поиск по имени или id"
                }
            }
        }

        Flickable {
            width: parent.width
            height: Math.max(120, parent.height - 280)
            clip: true
            contentHeight: cards.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: !PickerState.active

            Flow {
                id: cards

                width: parent.width
                spacing: Theme.space.sm

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
                        onDragFinished: {
                            if (PickerState.finish())
                                root.dismiss()
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            text: "Доступно: " + root.filtered.length
        }

        Text {
            width: parent.width
            visible: root.message.length > 0
            color: root.message.indexOf("Нет места") >= 0
                   ? Theme.error : Theme.scheme.onSurfaceVariant
            font: Theme.typeBodySmall
            wrapMode: Text.WordWrap
            text: root.message
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        Text {
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelLarge
            text: "Пользовательские пути"
        }

        Repeater {
            model: Config.extraPaths || []

            delegate: Text {
                required property var modelData

                width: parent.width
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                elide: Text.ElideMiddle
                text: modelData
            }
        }

        // Кнопка-пилюля 40 px (tonal): раскрывает поле ввода пути.
        Rectangle {
            id: pathToggle

            width: pathToggleLabel.implicitWidth + Theme.space.xl * 2
            height: Theme.buttonHeight
            radius: Theme.shape.full
            color: Theme.secondaryContainer

            Text {
                id: pathToggleLabel

                anchors.centerIn: parent
                text: root.showPathInput ? "Скрыть ввод пути" : "Добавить папку…"
                color: Theme.scheme.onSecondaryContainer
                font: Theme.typeLabelLarge
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.stateLayer(Theme.scheme.onSecondaryContainer,
                                        Theme.stateHover)
                visible: pathToggleHover.containsMouse
            }

            MouseArea {
                id: pathToggleHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showPathInput = !root.showPathInput
            }
        }

        Row {
            width: parent.width
            visible: root.showPathInput
            spacing: Theme.space.sm

            // Поле пути — такое же M3 filled-поле, как поиск.
            Item {
                width: Math.max(80, parent.width - 124)
                height: Theme.buttonHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shape.xs
                    color: Theme.surfaceContainerHighest
                    border.width: pathInput.activeFocus ? 2 : 1
                    border.color: pathInput.activeFocus ? Theme.primary : Theme.outline
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.motionShort3 }
                    }
                }

                TextInput {
                    id: pathInput

                    anchors.fill: parent
                    leftPadding: Theme.space.md
                    rightPadding: Theme.space.md
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyMedium
                    clip: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.md
                        verticalAlignment: Text.AlignVCenter
                        visible: pathInput.text.length === 0
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                        text: "/путь/к/папке"
                    }
                }
            }

            Rectangle {
                id: pathAdd

                width: pathAddLabel.implicitWidth + Theme.space.xl * 2
                height: Theme.buttonHeight
                radius: Theme.shape.full
                color: Theme.primary

                Text {
                    id: pathAddLabel

                    anchors.centerIn: parent
                    text: "Добавить"
                    color: Theme.scheme.onPrimary
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(Theme.scheme.onPrimary, Theme.stateHover)
                    visible: pathAddHover.containsMouse
                }

                MouseArea {
                    id: pathAddHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
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
}
