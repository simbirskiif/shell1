pragma ComponentBehavior: Bound

import QtQuick
import "../../singletons"
import "../core"

// Попап настроек экземпляра (раздел 8.6 ТЗ): материал, режим цвета,
// поля из manifest.settings, сброс и удаление.
Item {
    id: root

    required property string uid
    required property var screen
    required property var metrics

    readonly property var instance: LayoutStore.findInstance(root.uid)
    readonly property var widget: root.instance
                                   ? WidgetRegistry.widgetById(root.instance.id)
                                   : null
    readonly property string instanceMaterial:
        root.instance ? (root.instance.material || "") : ""
    readonly property string instanceColorMode:
        root.instance ? (root.instance.colorMode || "") : ""
    property var values: ({})

    // root.uid связан с EditorState.settingsUid, поэтому одной проверки
    // равенства мало: после закрытия оба становятся "" и попап оставался
    // пустым окном. Требуем непустой uid и существующий виджет.
    visible: root.uid.length > 0
             && root.widget !== null
             && root.screen !== null
             && EditorState.settingsScreen === root.screen.name
    anchors.fill: parent
    z: 130

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
        const allowed = root.widget && root.widget.materials
                      ? root.widget.materials : ["any"]
        const result = []
        if (allowed.indexOf("any") >= 0) {
            for (const material of MaterialRegistry.materials)
                result.push(material)
            return result
        }
        for (const id of allowed) {
            const material = MaterialRegistry.materialById(id)
            if (material)
                result.push(material)
        }
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

    onUidChanged: root.refreshValues()
    onWidgetChanged: {
        root.refreshValues()
        if (root.uid.length > 0 && root.widget === null)
            EditorState.closeSettings()
    }
    onVisibleChanged: {
        if (root.visible)
            root.refreshValues()
    }

    Connections {
        target: LayoutStore

        function onInstanceChanged(uid) {
            if (uid === root.uid)
                root.refreshValues()
        }

        function onLayoutChanged() {
            if (root.uid.length > 0 && !LayoutStore.findInstance(root.uid))
                EditorState.closeSettings()
        }
    }

    // Затемнение и перехват кликов вне панели.
    Rectangle {
        anchors.fill: parent
        color: "#55000000"
        visible: root.visible

        MouseArea {
            anchors.fill: parent
            onClicked: EditorState.closeSettings()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(380, parent.width - 24)
        height: Math.min(parent.height - 24, 520)
        radius: 14
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.outline

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width

                Text {
                    width: parent.width - 30
                    color: Theme.colors.onSurface
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
                color: Theme.colors.onSurfaceVariant
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
                color: Theme.colors.onSurfaceVariant
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

                Repeater {
                    model: root.widget ? root.widget.colorModes : []

                    delegate: HostButton {
                        required property var modelData

                        text: modelData === "accent" ? "Акцент"
                              : (modelData === "widget" ? "Палитра" : modelData)
                        active: root.instanceColorMode === modelData
                        onClicked: {
                            LayoutStore.setColorMode(root.uid, modelData)
                            root.refreshValues()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.colors.outline
                opacity: 0.4
            }

            Flickable {
                width: parent.width
                height: Math.max(80, parent.height - 250)
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
                                color: Theme.colors.onSurfaceVariant
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
                                       : Theme.colors.surfaceVariant

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    y: 3
                                    x: root.values[settingRow.modelData.key]
                                       ? parent.width - width - 3 : 3
                                    color: root.values[settingRow.modelData.key]
                                           ? Theme.colors.onPrimary
                                           : Theme.colors.onSurfaceVariant
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
                                color: Theme.colors.onSurface
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

            Row {
                width: parent.width
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

                Item { width: Math.max(0, parent.width - 220); height: 1 }

                HostButton {
                    text: "Закрыть"
                    onClicked: EditorState.closeSettings()
                }
            }
        }
    }
}
