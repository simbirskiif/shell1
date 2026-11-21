pragma ComponentBehavior: Bound

import QtQuick
import "../../components/quick"
import "../../components/expressive"
import "../../singletons"
import "../core"

// Настройки экземпляра (раздел 8.6 ТЗ): материал, режим цвета,
// поля из manifest.settings, сброс и удаление. Панель выезжает справа
// на всю высоту слоя и использует токены панелей оболочки.
//
// Expressive: крупный заголовок, секции — emphasized-подписи, материал/цвет —
// пилюли 40 (активная — tertiary-контейнер-«печенье»), переключатели —
// ToggleSwitch, поля ввода — крупные пилюли 48, действие — пилюли 48.
// Тонких разделителей нет: секции сгруппированы цветом и воздухом.
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
                text: root.widget ? root.widget.name : "Настройки"
            }

            HostIconButton {
                id: headerClose

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                onClicked: EditorState.closeSettings()
            }
        }

        Text {
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedLabelLarge
            text: "Материал"
        }

        Flow {
            width: parent.width
            spacing: Theme.space.sm

            HostButton {
                text: "По умолчанию"
                height: 40
                active: root.instanceMaterial.length === 0
                onClicked: {
                    LayoutStore.setMaterial(root.uid, "")
                    root.refreshValues()
                }
            }

            Repeater {
                model: root.materialChoices()

                delegate: HostButton {
                    required property var modelData

                    text: modelData.name
                    height: 40
                    active: root.instanceMaterial === modelData.id
                    onClicked: {
                        LayoutStore.setMaterial(root.uid, modelData.id)
                        root.refreshValues()
                    }
                }
            }
        }

        Text {
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedLabelLarge
            text: "Режим цвета"
        }

        Flow {
            width: parent.width
            spacing: Theme.space.sm

            HostButton {
                text: "По умолчанию"
                height: 40
                active: root.instanceColorMode.length === 0
                onClicked: {
                    LayoutStore.setColorMode(root.uid, "")
                    root.refreshValues()
                }
            }

            HostButton {
                text: "Акцент"
                height: 40
                active: root.instanceColorMode === "accent"
                onClicked: {
                    LayoutStore.setColorMode(root.uid, "accent")
                    root.refreshValues()
                }
            }

            HostButton {
                text: "Нейтральная"
                height: 40
                active: root.instanceColorMode === "neutral"
                onClicked: {
                    LayoutStore.setColorMode(root.uid, "neutral")
                    root.refreshValues()
                }
            }
        }

        Text {
            color: Theme.scheme.onSurface
            font: Theme.typeEmphasizedLabelLarge
            text: "Затемнение материала"
        }

        Row {
            width: parent.width
            spacing: Theme.space.sm

            PanelSlider {
                width: Math.max(80, parent.width - 56)
                accent: Theme.tertiary
                value: root.dim
                onMoved: value => LayoutStore.setDim(root.uid, value)
            }

            Text {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                color: Theme.tertiary
                font: Theme.typeEmphasizedLabelLarge
                text: Math.round(root.dim * 100) + "%"
            }
        }

        HostButton {
            text: "По умолчанию"
            height: 40
            active: !root.dimOverridden
            onClicked: LayoutStore.setDim(root.uid, NaN)
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
            spacing: Theme.space.xs

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
                        color: Theme.scheme.onSurface
                        font: Theme.typeBodyMedium
                        elide: Text.ElideRight
                        text: settingRow.modelData.label
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
                        spacing: Theme.space.xs
                        visible: settingRow.modelData.type === "enum"

                        Repeater {
                            model: settingRow.modelData.options || []

                            delegate: HostButton {
                                required property var modelData

                                text: String(modelData)
                                height: 40
                                active: String(root.values[settingRow.modelData.key])
                                        === String(modelData)
                                onClicked: root.setValue(settingRow.modelData.key,
                                                         modelData)
                            }
                        }
                    }

                    // Крупное Expressive-поле: пилюля surface-container-highest,
                    // в фокусе — squircle с primary-контуром.
                    Item {
                        id: fieldBox

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(96, parent.width * 0.5)
                        height: 48
                        visible: settingRow.modelData.type !== "bool"
                                 && settingRow.modelData.type !== "enum"

                        MorphShape {
                            anchors.fill: parent
                            shape: field.activeFocus ? "squircle" : "pill"
                            modulation: 0.35
                            color: Theme.surfaceContainerHighest
                            borderWidth: field.activeFocus ? 2 : 0
                            borderColor: Theme.primary
                        }

                        TextInput {
                            id: field

                            anchors.fill: parent
                            leftPadding: Theme.space.lg
                            rightPadding: Theme.space.lg
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.scheme.onSurface
                            font: Theme.typeBodyLarge
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
        height: 48

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm

            HostButton {
                text: "Сбросить"
                height: 48
                onClicked: root.reset()
            }

            // Удаление — единственное действие с error-ролью: заметный
            // error-контейнер, а не красный текст без подложки.
            Item {
                id: deleteAction

                width: deleteActionLabel.implicitWidth + Theme.space.xxl
                height: 48
                scale: deleteActionHover.pressed ? 0.94
                     : (deleteActionHover.containsMouse ? 1.04 : 1)
                Behavior on scale { SpringSpatial {} }

                MorphShape {
                    anchors.fill: parent
                    shape: deleteActionHover.pressed ? "squircle" : "pill"
                    modulation: 0.4
                    color: deleteActionHover.containsMouse
                           ? Theme.mix(Theme.errorContainer,
                                       Theme.scheme.onErrorContainer, Theme.stateHover)
                           : Theme.errorContainer
                    borderWidth: 0
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: deleteActionLabel

                    anchors.centerIn: parent
                    text: "Удалить"
                    color: Theme.scheme.onErrorContainer
                    font: Theme.typeEmphasizedLabelLarge
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

        HostButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Закрыть"
            height: 48
            prominent: true
            onClicked: EditorState.closeSettings()
        }
    }
}
