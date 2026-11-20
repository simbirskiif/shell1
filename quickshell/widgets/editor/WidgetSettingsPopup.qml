pragma ComponentBehavior: Bound

import QtQuick
import "../../components/quick"
import "../../singletons"
import "../core"

// Настройки экземпляра (раздел 8.6 ТЗ): материал, режим цвета,
// поля из manifest.settings, сброс и удаление. Панель выезжает справа
// на всю высоту слоя и использует токены панелей оболочки.
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
        spacing: 8

        Row {
            width: parent.width

            Text {
                width: parent.width - 30
                color: Theme.quickText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                text: root.widget ? root.widget.name : "Настройки"
            }

            HostButton {
                text: "✕"
                onClicked: EditorState.closeSettings()
            }
        }

        Text {
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            text: "Материал"
        }

        Flow {
            width: parent.width
            spacing: 4

            HostButton {
                text: "По умолчанию"
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
                    active: root.instanceMaterial === modelData.id
                    onClicked: {
                        LayoutStore.setMaterial(root.uid, modelData.id)
                        root.refreshValues()
                    }
                }
            }
        }

        Text {
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            text: "Режим цвета"
        }

        Row {
            spacing: 4

            HostButton {
                text: "По умолчанию"
                active: root.instanceColorMode.length === 0
                onClicked: {
                    LayoutStore.setColorMode(root.uid, "")
                    root.refreshValues()
                }
            }

            HostButton {
                text: "Акцент"
                active: root.instanceColorMode === "accent"
                onClicked: {
                    LayoutStore.setColorMode(root.uid, "accent")
                    root.refreshValues()
                }
            }

            HostButton {
                text: "Нейтральная"
                active: root.instanceColorMode === "neutral"
                onClicked: {
                    LayoutStore.setColorMode(root.uid, "neutral")
                    root.refreshValues()
                }
            }
        }

        Text {
            color: Theme.quickTextDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            text: "Затемнение материала"
        }

        Row {
            width: parent.width
            spacing: 8

            PanelSlider {
                width: Math.max(80, parent.width - 48)
                value: root.dim
                onMoved: value => LayoutStore.setDim(root.uid, value)
            }

            Text {
                width: 40
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                text: Math.round(root.dim * 100) + "%"
            }
        }

        HostButton {
            text: "По умолчанию"
            active: !root.dimOverridden
            onClicked: LayoutStore.setDim(root.uid, NaN)
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.quickSeparator
            opacity: 0.4
        }
    }

    // Поля settings из манифеста: прокручиваются в остатке высоты панели.
    // Футер закреплён у нижней кромки, поэтому «Удалить/Закрыть» больше не
    // уезжают за границу экрана на длинном списке полей.
    Flickable {
        id: fieldsScroll

        anchors.top: fixedTop.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: 8
        clip: true
        contentHeight: settingsColumn.height
        boundsBehavior: Flickable.StopAtBounds


            Column {
                id: settingsColumn

                width: parent.width
                spacing: 6

                Repeater {
                    model: root.widget ? root.widget.settingsSchema : []

                    delegate: Item {
                        id: settingRow

                        required property var modelData

                        width: settingsColumn.width
                        height: settingRow.modelData.type === "enum" ? 52 : 32

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.45
                            color: Theme.quickTextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            text: settingRow.modelData.label
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: settingRow.modelData.type === "bool"
                            width: 42
                            height: 24
                            radius: 12
                            color: root.values[settingRow.modelData.key]
                                   ? Theme.colors.primary
                                   : Theme.quickTile

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                y: 3
                                x: root.values[settingRow.modelData.key]
                                   ? parent.width - width - 3 : 3
                                color: root.values[settingRow.modelData.key]
                                       ? Theme.colors.onPrimary
                                       : Theme.quickTextDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setValue(settingRow.modelData.key,
                                                         !root.values[settingRow.modelData.key])
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            visible: settingRow.modelData.type === "enum"

                            Repeater {
                                model: settingRow.modelData.options || []

                                delegate: HostButton {
                                    required property var modelData

                                    text: String(modelData)
                                    onClicked: root.setValue(settingRow.modelData.key,
                                                             modelData)
                                }
                            }
                        }

                        TextInput {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, parent.width * 0.5)
                            height: 26
                            padding: 4
                            visible: settingRow.modelData.type !== "bool"
                                     && settingRow.modelData.type !== "enum"
                            color: Theme.quickText
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            clip: true
                            selectionColor: Theme.colors.primary
                            text: root.values[settingRow.modelData.key] !== undefined
                                  ? String(root.values[settingRow.modelData.key]) : ""
                            onEditingFinished: root.setValue(settingRow.modelData.key, text)
                        }
                    }
                }
            }
        }

    // Футер закреплён внизу: «Сбросить/Удалить/Закрыть» видны всегда.
    Row {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 6

        HostButton {
            text: "Сбросить"
            onClicked: root.reset()
        }

        HostButton {
            text: "Удалить"
            onClicked: {
                EditorState.beginOperation()
                LayoutStore.removeInstance(root.uid)
                EditorState.closeSettings()
            }
        }

        Item { width: Math.max(0, footer.width - 220); height: 1 }

        HostButton {
            text: "Закрыть"
            onClicked: EditorState.closeSettings()
        }
    }
}
