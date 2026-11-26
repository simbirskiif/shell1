pragma ComponentBehavior: Bound

import QtQuick
import "../../components/quick"
import "../../singletons"
import "../core"

// Настройки экземпляра (раздел 8.6 ТЗ): материал, режим цвета,
// поля из manifest.settings, сброс и удаление. Панель выезжает справа
// на всю высоту слоя и использует токены панелей оболочки.
//
// Оформление — M3: шапка top app bar (titleLarge + иконка 40), секции
// labelLarge, выбор материала/цвета — filter chips, переключатели —
// ToggleSwitch, поля — filled (surface-container-highest, radius xs,
// обводка outline), строки списка 56 px, действия — пилюли 40 px.
SidePanel {
    id: root

    required property string uid
    required property var screen
    required property var metrics

    // LayoutStore меняет поля существующего объекта, а не заменяет его.
    // Без явного счётчика readonly-биндинги ниже не узнают об изменении
    // colorMode/material/dim и кнопки панели остаются на старой вкладке.
    property int instanceRevision: 0

    readonly property var instance: LayoutStore.findInstance(root.uid)
    readonly property var widget: root.instance
                                   ? WidgetRegistry.widgetById(root.instance.id)
                                   : null
    readonly property string instanceMaterial: {
        root.instanceRevision
        return root.instance ? (root.instance.material || "") : ""
    }
    readonly property string instanceColorMode: {
        root.instanceRevision
        return root.instance ? (root.instance.colorMode || "") : ""
    }
    readonly property real dim: {
        root.instanceRevision
        return root.instance && Number.isFinite(root.instance.dim)
               ? root.instance.dim : Config.defaultMaterialDim
    }
    readonly property bool dimOverridden: {
        root.instanceRevision
        return root.instance && Number.isFinite(root.instance.dim)
    }
    property var values: ({})

    // root.uid связан с EditorState.settingsUid, поэтому одной проверки
    // равенства мало: после закрытия оба становятся "" и попап оставался
    // пустым окном. Требуем непустой uid и существующий виджет.
    opened: root.uid.length > 0
            && root.widget !== null
            && root.screen !== null
            && EditorState.settingsScreen === root.screen.name

    onClosed: EditorState.closeSettings()

    function refreshValues(): void {
        root.values = root.widget ? LayoutStore.settingsFor(root.uid, root.widget) : ({})
    }

    function setValue(key: string, value: var): void {
        const schema = root.widget ? root.widget.settingsSchema : []
        for (const setting of schema) {
            if (setting.key !== key)
                continue
            let normalized = value
            if (setting.type === "int") {
                normalized = Math.round(Number(value))
                if (!Number.isFinite(normalized))
                    return
                if (Number.isFinite(setting.min))
                    normalized = Math.max(normalized, setting.min)
                if (Number.isFinite(setting.max))
                    normalized = Math.min(normalized, setting.max)
            } else if (setting.type === "real") {
                normalized = Number(value)
                if (!Number.isFinite(normalized))
                    return
                if (Number.isFinite(setting.min))
                    normalized = Math.max(normalized, setting.min)
                if (Number.isFinite(setting.max))
                    normalized = Math.min(normalized, setting.max)
            }
            LayoutStore.setSetting(root.uid, key, normalized)
            root.refreshValues()
            return
        }
    }

    function materialChoices(): var {
        // Материал назначает система; ограничения из манифеста больше не
        // участвуют в выборе.
        const result = []
        for (const material of MaterialRegistry.materials)
            result.push(material)
        return result
    }

    function reset(): void {
        EditorState.beginOperation()
        if (!root.widget)
            return
        for (const setting of root.widget.settingsSchema)
            LayoutStore.setSetting(root.uid, setting.key, setting.default)
        LayoutStore.setMaterial(root.uid, "")
        LayoutStore.setColorMode(root.uid, "")
        root.refreshValues()
    }

    Component.onCompleted: root.refreshValues()

    onUidChanged: {
        root.instanceRevision++
        root.refreshValues()
    }
    onWidgetChanged: {
        root.refreshValues()
        if (root.uid.length > 0 && root.widget === null)
            EditorState.closeSettings()
    }
    onOpenedChanged: {
        if (root.opened) {
            root.instanceRevision++
            root.refreshValues()
        }
    }

    Connections {
        target: LayoutStore

        function onInstanceChanged(uid) {
            if (uid === root.uid) {
                root.instanceRevision++
                root.refreshValues()
            }
        }

        function onLayoutChanged() {
            if (root.uid.length > 0 && !LayoutStore.findInstance(root.uid))
                EditorState.closeSettings()
        }
    }

    // Шапка и общие параметры материала закреплены сверху: так видно, что
    // меняешь, даже когда список полей прокручен.
    Column {
        id: fixedTop

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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
                text: root.widget
                      ? WidgetRegistry.displayName(root.widget)
                      : I18n.tr("settings.window.title")
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
                    onClicked: EditorState.closeSettings()
                }
            }
        }

        Text {
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelLarge
            text: I18n.tr("widgets.material")
        }

        Flow {
            width: parent.width
            spacing: Theme.space.sm

            Rectangle {
                id: defaultMaterialChip

                readonly property bool selected: root.instanceMaterial.length === 0

                width: defaultMaterialLabel.implicitWidth + Theme.space.lg * 2
                height: 32
                radius: Theme.shape.full
                color: defaultMaterialChip.selected ? Theme.secondaryContainer
                                                    : "transparent"
                border.width: 1
                border.color: defaultMaterialChip.selected ? Theme.secondaryContainer
                                                           : Theme.outline

                Text {
                    id: defaultMaterialLabel

                    anchors.centerIn: parent
                    text: I18n.tr("common.default")
                    color: defaultMaterialChip.selected
                           ? Theme.scheme.onSecondaryContainer
                           : Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(defaultMaterialChip.selected
                                            ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface,
                                            Theme.stateHover)
                    visible: defaultMaterialHover.containsMouse
                }

                MouseArea {
                    id: defaultMaterialHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LayoutStore.setMaterial(root.uid, "")
                        root.refreshValues()
                    }
                }
            }

            Repeater {
                model: root.materialChoices()

                delegate: Rectangle {
                    id: materialChip

                    required property var modelData

                    readonly property bool selected:
                        root.instanceMaterial === materialChip.modelData.id

                    width: materialChipLabel.implicitWidth + Theme.space.lg * 2
                    height: 32
                    radius: Theme.shape.full
                    color: materialChip.selected ? Theme.secondaryContainer
                                                : "transparent"
                    border.width: 1
                    border.color: materialChip.selected ? Theme.secondaryContainer
                                                        : Theme.outline

                    Text {
                        id: materialChipLabel

                        anchors.centerIn: parent
                        text: I18n.trOr("material." + materialChip.modelData.id + ".name",
                                        materialChip.modelData.name)
                        color: materialChip.selected
                               ? Theme.scheme.onSecondaryContainer
                               : Theme.scheme.onSurfaceVariant
                        font: Theme.typeLabelLarge
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.stateLayer(materialChip.selected
                                                ? Theme.scheme.onSecondaryContainer
                                                : Theme.scheme.onSurface,
                                                Theme.stateHover)
                        visible: materialChipHover.containsMouse
                    }

                    MouseArea {
                        id: materialChipHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            LayoutStore.setMaterial(root.uid, materialChip.modelData.id)
                            root.refreshValues()
                        }
                    }
                }
            }
        }

        Text {
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelLarge
            text: I18n.tr("widgets.colorMode")
        }

        Row {
            spacing: Theme.space.sm

            Rectangle {
                id: defaultModeChip

                readonly property bool selected: root.instanceColorMode.length === 0

                width: defaultModeLabel.implicitWidth + Theme.space.lg * 2
                height: 32
                radius: Theme.shape.full
                color: defaultModeChip.selected ? Theme.secondaryContainer : "transparent"
                border.width: 1
                border.color: defaultModeChip.selected ? Theme.secondaryContainer
                                                       : Theme.outline

                Text {
                    id: defaultModeLabel

                    anchors.centerIn: parent
                    text: I18n.tr("common.default")
                    color: defaultModeChip.selected
                           ? Theme.scheme.onSecondaryContainer
                           : Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(defaultModeChip.selected
                                            ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface,
                                            Theme.stateHover)
                    visible: defaultModeHover.containsMouse
                }

                MouseArea {
                    id: defaultModeHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LayoutStore.setColorMode(root.uid, "")
                        root.refreshValues()
                    }
                }
            }

            Rectangle {
                id: accentChip

                readonly property bool selected: root.instanceColorMode === "accent"

                width: accentChipLabel.implicitWidth + Theme.space.lg * 2
                height: 32
                radius: Theme.shape.full
                color: accentChip.selected ? Theme.secondaryContainer : "transparent"
                border.width: 1
                border.color: accentChip.selected ? Theme.secondaryContainer
                                                  : Theme.outline

                Text {
                    id: accentChipLabel

                    anchors.centerIn: parent
                    text: I18n.tr("widgets.colorMode.accent")
                    color: accentChip.selected
                           ? Theme.scheme.onSecondaryContainer
                           : Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(accentChip.selected
                                            ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface,
                                            Theme.stateHover)
                    visible: accentChipHover.containsMouse
                }

                MouseArea {
                    id: accentChipHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LayoutStore.setColorMode(root.uid, "accent")
                        root.refreshValues()
                    }
                }
            }

            Rectangle {
                id: neutralChip

                readonly property bool selected: root.instanceColorMode === "neutral"

                width: neutralChipLabel.implicitWidth + Theme.space.lg * 2
                height: 32
                radius: Theme.shape.full
                color: neutralChip.selected ? Theme.secondaryContainer : "transparent"
                border.width: 1
                border.color: neutralChip.selected ? Theme.secondaryContainer
                                                   : Theme.outline

                Text {
                    id: neutralChipLabel

                    anchors.centerIn: parent
                    text: I18n.tr("widgets.colorMode.neutral")
                    color: neutralChip.selected
                           ? Theme.scheme.onSecondaryContainer
                           : Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(neutralChip.selected
                                            ? Theme.scheme.onSecondaryContainer
                                            : Theme.scheme.onSurface,
                                            Theme.stateHover)
                    visible: neutralChipHover.containsMouse
                }

                MouseArea {
                    id: neutralChipHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LayoutStore.setColorMode(root.uid, "neutral")
                        root.refreshValues()
                    }
                }
            }
        }

        Text {
            color: Theme.scheme.onSurfaceVariant
            font: Theme.typeLabelLarge
            text: I18n.tr("widgets.materialDim")
        }

        Row {
            width: parent.width
            spacing: Theme.space.sm

            PanelSlider {
                width: Math.max(80, parent.width - 48)
                value: root.dim
                onMoved: value => LayoutStore.setDim(root.uid, value)
            }

            Text {
                width: 40
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelMedium
                text: Math.round(root.dim * 100) + "%"
            }
        }

        Rectangle {
            id: defaultDimChip

            readonly property bool selected: !root.dimOverridden

            width: defaultDimLabel.implicitWidth + Theme.space.lg * 2
            height: 32
            radius: Theme.shape.full
            color: defaultDimChip.selected ? Theme.secondaryContainer : "transparent"
            border.width: 1
            border.color: defaultDimChip.selected ? Theme.secondaryContainer
                                                  : Theme.outline

            Text {
                id: defaultDimLabel

                anchors.centerIn: parent
                text: I18n.tr("common.default")
                color: defaultDimChip.selected
                       ? Theme.scheme.onSecondaryContainer
                       : Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.stateLayer(defaultDimChip.selected
                                        ? Theme.scheme.onSecondaryContainer
                                        : Theme.scheme.onSurface,
                                        Theme.stateHover)
                visible: defaultDimHover.containsMouse
            }

            MouseArea {
                id: defaultDimHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LayoutStore.setDim(root.uid, NaN)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }
    }

    // Поля settings из манифеста: прокручиваются в остатке высоты панели.
    // Футер закреплён у нижней кромки, поэтому «Удалить/Закрыть» больше не
    // уезжают за границу экрана на длинном списке полей.
    Flickable {
        id: fieldsScroll

        anchors.top: fixedTop.bottom
        anchors.topMargin: Theme.space.sm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.space.sm
        clip: true
        contentHeight: settingsColumn.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: settingsColumn

            width: parent.width
            spacing: 0

            Repeater {
                model: root.widget ? root.widget.settingsSchema : []

                delegate: Item {
                    id: settingRow

                    required property var modelData

                    width: settingsColumn.width
                    // Строка списка M3: 56 px на любое поле, чтобы подпись и
                    // контрол попадали в один ритм.
                    height: Theme.listItemHeight

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.45
                        color: Theme.scheme.onSurfaceVariant
                        font: Theme.typeBodyMedium
                        elide: Text.ElideRight
                        text: WidgetRegistry.displaySettingLabel(root.widget,
                                                                 settingRow.modelData)
                    }

                    // Переключатель — общий M3-компонент, не локальная копия.
                    ToggleSwitch {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: settingRow.modelData.type === "bool"
                        checked: !!root.values[settingRow.modelData.key]
                        onToggled: root.setValue(settingRow.modelData.key,
                                                 !root.values[settingRow.modelData.key])
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.sm
                        visible: settingRow.modelData.type === "enum"

                        Repeater {
                            model: settingRow.modelData.options || []

                            delegate: Rectangle {
                                id: optionChip

                                required property var modelData

                                readonly property bool selected:
                                    String(root.values[settingRow.modelData.key])
                                    === String(optionChip.modelData)

                                width: optionChipLabel.implicitWidth + Theme.space.lg * 2
                                height: 32
                                radius: Theme.shape.full
                                color: optionChip.selected ? Theme.secondaryContainer
                                                           : "transparent"
                                border.width: 1
                                border.color: optionChip.selected
                                              ? Theme.secondaryContainer : Theme.outline

                                Text {
                                    id: optionChipLabel

                                    anchors.centerIn: parent
                                    text: WidgetRegistry.displaySettingOption(
                                              root.widget, settingRow.modelData.key,
                                              optionChip.modelData)
                                    color: optionChip.selected
                                           ? Theme.scheme.onSecondaryContainer
                                           : Theme.scheme.onSurfaceVariant
                                    font: Theme.typeLabelLarge
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Theme.stateLayer(optionChip.selected
                                                            ? Theme.scheme.onSecondaryContainer
                                                            : Theme.scheme.onSurface,
                                                            Theme.stateHover)
                                    visible: optionChipHover.containsMouse
                                }

                                MouseArea {
                                    id: optionChipHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setValue(settingRow.modelData.key,
                                                             optionChip.modelData)
                                }
                            }
                        }
                    }

                    // M3 filled-поле: контейнер surface-container-highest,
                    // радиус xs, обводка outline (в фокусе — primary, 2).
                    Item {
                        id: fieldBox

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(80, parent.width * 0.5)
                        height: 48
                        visible: settingRow.modelData.type !== "bool"
                                 && settingRow.modelData.type !== "enum"

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.shape.xs
                            color: Theme.surfaceContainerHighest
                            border.width: field.activeFocus ? 2 : 1
                            border.color: field.activeFocus ? Theme.primary
                                                            : Theme.outline
                            Behavior on border.color {
                                ColorAnimation { duration: Theme.motionShort3 }
                            }
                        }

                        TextInput {
                            id: field

                            anchors.fill: parent
                            leftPadding: Theme.space.md
                            rightPadding: Theme.space.md
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyMedium
                            clip: true
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.scheme.onPrimary
                            text: root.values[settingRow.modelData.key] !== undefined
                                  ? String(root.values[settingRow.modelData.key]) : ""
                            onEditingFinished: root.setValue(
                                settingRow.modelData.key, text)
                        }
                    }
                }
            }
        }
    }

    // Футер закреплён внизу: «Сбросить/Удалить/Закрыть» видны всегда.
    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.buttonHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm

            Rectangle {
                id: resetAction

                width: resetActionLabel.implicitWidth + Theme.space.xl * 2
                height: Theme.buttonHeight
                radius: Theme.shape.full
                color: "transparent"

                Text {
                    id: resetActionLabel

                    anchors.centerIn: parent
                    text: I18n.tr("common.reset")
                    color: Theme.primary
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(Theme.primary, Theme.stateHover)
                    visible: resetActionHover.containsMouse
                }

                MouseArea {
                    id: resetActionHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }

            Rectangle {
                id: deleteAction

                width: deleteActionLabel.implicitWidth + Theme.space.xl * 2
                height: Theme.buttonHeight
                radius: Theme.shape.full
                color: "transparent"

                Text {
                    id: deleteActionLabel

                    anchors.centerIn: parent
                    text: I18n.tr("common.delete")
                    color: Theme.error
                    font: Theme.typeLabelLarge
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.stateLayer(Theme.error, Theme.stateHover)
                    visible: deleteActionHover.containsMouse
                }

                MouseArea {
                    id: deleteActionHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        EditorState.beginOperation()
                        LayoutStore.removeInstance(root.uid)
                        EditorState.closeSettings()
                    }
                }
            }
        }

        Rectangle {
            id: closeAction

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: closeActionLabel.implicitWidth + Theme.space.xl * 2
            height: Theme.buttonHeight
            radius: Theme.shape.full
            color: Theme.primary

            Text {
                id: closeActionLabel

                anchors.centerIn: parent
                text: I18n.tr("common.close")
                color: Theme.scheme.onPrimary
                font: Theme.typeLabelLarge
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.stateLayer(Theme.scheme.onPrimary, Theme.stateHover)
                visible: closeActionHover.containsMouse
            }

            MouseArea {
                id: closeActionHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: EditorState.closeSettings()
            }
        }
    }
}
