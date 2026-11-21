pragma ComponentBehavior: Bound

import QtQuick
import "../../components/expressive"
import "../../singletons"
import "../core"

// Каталог виджетов (раздел 8.5 ТЗ): поиск, превью, добавление тапом,
// drag-and-drop на сетку, список пользовательских путей и «Добавить папку…».
//
// Expressive: side sheet с крупной squircle-формой, заголовок
// typeEmphasized*, поиск — крупная пилюля 56, карточки — цветные
// контейнеры, действия — пилюли 48. Появление/уход — на пружинах.
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

    Behavior on opacity { SpringEffects {} }
    Behavior on slideOffset { SpringSpatial {} }

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

    // Крупная форма листа: большой левый радиус (для высокой панели
    // MorphShape даёт слишком круглые углы и режет шапку).
    Rectangle {
        anchors.fill: parent
        topLeftRadius: Theme.shape.xlIncreased
        bottomLeftRadius: Theme.shape.xlIncreased
        topRightRadius: 0
        bottomRightRadius: 0
        color: Theme.panelSurface
        border.width: 0
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.space.lg
        spacing: Theme.space.sm

        // Шапка — Expressive top app bar: крупный заголовок и icon-кнопка.
        Item {
            width: parent.width
            height: Theme.appBarHeight

            Text {
                anchors.left: parent.left
                anchors.right: headerClose.left
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedTitleLarge
                elide: Text.ElideRight
                text: "Виджеты"
            }

            HostIconButton {
                id: headerClose

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                onClicked: root.dismiss()
            }
        }

        // Поиск — крупная Expressive-пилюля 56: тональная заливка без
        // постоянной обводки, в фокусе — primary-контур.
        Item {
            width: parent.width
            height: 56

            MorphShape {
                anchors.fill: parent
                shape: search.activeFocus ? "squircle" : "pill"
                modulation: 0.35
                color: Theme.surfaceContainerHighest
                borderWidth: search.activeFocus ? 2 : 0
                borderColor: Theme.primary
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            TextInput {
                id: search

                anchors.fill: parent
                leftPadding: Theme.space.xl
                rightPadding: Theme.space.xl
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.scheme.onSurface
                font: Theme.typeBodyLarge
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
                    anchors.leftMargin: Theme.space.xl
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text.length === 0
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeBodyLarge
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

                        // Две карточки ровно по ширине листа: без пустого
                        // правого края, который читался как обрезанный ряд.
                        width: Math.max(140, Math.floor((cards.width - cards.spacing) / 2))
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
            font: Theme.typeLabelMedium
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

        // Группировка цветом и воздухом вместо тонкого разделителя.
        Text {
            topPadding: Theme.space.sm
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedLabelLarge
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

        // Кнопка-пилюля 48 (tonal): раскрывает поле ввода пути. Форма —
        // tertiary-контейнер, на hover перетекает в cookie, на press сжимается.
        Item {
            id: pathToggle

            width: pathToggleLabel.implicitWidth + Theme.space.xxl
            height: 48
            scale: pathToggleHover.pressed ? 0.95 : (pathToggleHover.containsMouse ? 1.03 : 1)
            Behavior on scale { SpringSpatial {} }

            MorphShape {
                anchors.fill: parent
                shape: pathToggleHover.pressed ? "squircle"
                     : pathToggleHover.containsMouse ? "cookie"
                     : "pill"
                modulation: 0.4
                color: pathToggleHover.containsMouse ? Theme.tertiaryContainer
                                                     : Theme.secondaryContainer
                borderWidth: 0
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                id: pathToggleLabel

                anchors.centerIn: parent
                text: root.showPathInput ? "Скрыть ввод пути" : "Добавить папку…"
                color: pathToggleHover.containsMouse ? Theme.scheme.onTertiaryContainer
                                                     : Theme.scheme.onSecondaryContainer
                font: Theme.typeEmphasizedLabelLarge
                Behavior on color { ColorAnimation { duration: 140 } }
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

            // Поле пути — такая же крупная пилюля, как поиск.
            Item {
                width: Math.max(80, parent.width - 124)
                height: 48

                MorphShape {
                    anchors.fill: parent
                    shape: pathInput.activeFocus ? "squircle" : "pill"
                    modulation: 0.35
                    color: Theme.surfaceContainerHighest
                    borderWidth: pathInput.activeFocus ? 2 : 0
                    borderColor: Theme.primary
                }

                TextInput {
                    id: pathInput

                    anchors.fill: parent
                    leftPadding: Theme.space.lg
                    rightPadding: Theme.space.lg
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.scheme.onSurface
                    font: Theme.typeBodyMedium
                    clip: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.scheme.onPrimary

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.lg
                        verticalAlignment: Text.AlignVCenter
                        visible: pathInput.text.length === 0
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                        text: "/путь/к/папке"
                    }
                }
            }

            Item {
                id: pathAdd

                width: pathAddLabel.implicitWidth + Theme.space.xxl
                height: 48
                scale: pathAddHover.pressed ? 0.94 : (pathAddHover.containsMouse ? 1.04 : 1)
                Behavior on scale { SpringSpatial {} }

                MorphShape {
                    anchors.fill: parent
                    shape: pathAddHover.pressed ? "squircle" : "pill"
                    modulation: 0.4
                    color: pathAddHover.containsMouse
                           ? Theme.mix(Theme.primary, Theme.scheme.onPrimary,
                                       Theme.stateHover)
                           : Theme.primary
                    borderWidth: 0
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: pathAddLabel

                    anchors.centerIn: parent
                    text: "Добавить"
                    color: Theme.scheme.onPrimary
                    font: Theme.typeEmphasizedLabelLarge
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
