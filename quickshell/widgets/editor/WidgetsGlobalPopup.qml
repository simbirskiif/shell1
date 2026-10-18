pragma ComponentBehavior: Bound

import QtQuick
import "../../singletons"
import "../core"

// Глобальные параметры виджетов (материал и режим цвета по умолчанию).
// Это тот же слой/окно рабочего стола, отдельного окна настроек нет.
Item {
    id: root

    required property var screen

    property string message: ""

    visible: EditorState.globalOpen
             && root.screen !== null
             && EditorState.uiScreen === root.screen.name
    anchors.fill: parent
    z: 132

    function chooseMaterial(id: string): void {
        if (Config.setDefaultMaterial(id))
            root.message = "Материал по умолчанию: " + id
    }

    function chooseColorMode(mode: string): void {
        if (Config.setDefaultColorMode(mode))
            root.message = "Цвет по умолчанию: " + mode
    }

    Rectangle {
        anchors.fill: parent
        color: "#55000000"

        MouseArea {
            anchors.fill: parent
            onClicked: EditorState.closeGlobalSettings()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(400, parent.width - 24)
        height: Math.min(parent.height - 24, 380)
        radius: 14
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.outline

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width

                Text {
                    width: parent.width - 34
                    color: Theme.colors.onSurface
                    font.pixelSize: 16
                    font.bold: true
                    text: "Параметры виджетов"
                }

                HostButton {
                    text: "✕"
                    onClicked: EditorState.closeGlobalSettings()
                }
            }

            Text {
                width: parent.width
                color: Theme.colors.onSurfaceVariant
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                text: "Действуют для всех виджетов, пока экземпляр не переопределил "
                      + "материал или цвет в своих настройках."
            }

            Text {
                color: Theme.colors.onSurfaceVariant
                font.pixelSize: 11
                text: "Материал по умолчанию"
            }

            Flow {
                width: parent.width
                spacing: 4

                Repeater {
                    model: MaterialRegistry.materials

                    delegate: HostButton {
                        required property var modelData

                        text: modelData.name
                        active: Config.defaultMaterial === modelData.id
                        onClicked: root.chooseMaterial(modelData.id)
                    }
                }
            }

            Text {
                color: Theme.colors.onSurfaceVariant
                font.pixelSize: 11
                text: "Цвет по умолчанию"
            }

            Row {
                spacing: 4

                HostButton {
                    text: "Акцент"
                    active: Config.defaultColorMode === "accent"
                    onClicked: root.chooseColorMode("accent")
                }

                HostButton {
                    text: "Палитра виджета"
                    active: Config.defaultColorMode === "widget"
                    onClicked: root.chooseColorMode("widget")
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.colors.outline
                opacity: 0.4
            }

            Text {
                width: parent.width
                color: Theme.colors.onSurfaceVariant
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                text: root.message.length > 0
                      ? root.message
                      : "Экземпляры с выбранным «По умолчанию» следуют этим значениям."
            }

            Item { width: 1; height: Math.max(0, parent.height - 300) }

            Row {
                width: parent.width
                spacing: 6

                HostButton {
                    text: "Сбросить переопределения"
                    onClicked: {
                        EditorState.beginOperation()
                        const count = LayoutStore.clearOverrides()
                        root.message = count > 0
                                     ? "Сброшено переопределений: " + count
                                     : "Переопределений нет"
                    }
                }

                Item { width: Math.max(0, parent.width - 220); height: 1 }

                HostButton {
                    text: "Закрыть"
                    onClicked: EditorState.closeGlobalSettings()
                }
            }
        }
    }
}
