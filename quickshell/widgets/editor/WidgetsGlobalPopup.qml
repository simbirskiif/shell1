pragma ComponentBehavior: Bound

import QtQuick
import "../../components/quick"
import "../../singletons"
import "../core"

// Глобальные параметры виджетов (материал и режим цвета по умолчанию).
// Это тот же слой/окно рабочего стола, отдельного окна настроек нет.
SidePanel {
    id: root

    required property var screen

    property string message: ""

    opened: EditorState.globalOpen
            && root.screen !== null
            && EditorState.uiScreen === root.screen.name

    onClosed: EditorState.closeGlobalSettings()

    function chooseMaterial(id: string): void {
        if (Config.setDefaultMaterial(id))
            root.message = "Материал по умолчанию: " + id
    }

    function chooseColorMode(mode: string): void {
        if (Config.setDefaultColorMode(mode))
            root.message = "Цвет по умолчанию: " + mode
    }

    Column {
        id: layout

        anchors.fill: parent
        spacing: 10

            Row {
                width: parent.width

                Text {
                    width: parent.width - 34
                    color: Theme.quickText
                    font.family: Theme.fontFamily
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
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                text: "Действуют для всех виджетов, пока экземпляр не переопределил "
                      + "материал или цвет в своих настройках."
            }

            Text {
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
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
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
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
                    text: "Нейтральная"
                    active: Config.defaultColorMode === "neutral"
                    onClicked: root.chooseColorMode("neutral")
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
                    value: Config.defaultMaterialDim
                    onMoved: value => Config.setDefaultMaterialDim(value)
                }

                Text {
                    width: 40
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    color: Theme.quickTextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    text: Math.round(Config.defaultMaterialDim * 100) + "%"
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.quickSeparator
                opacity: 0.4
            }

            Text {
                width: parent.width
                color: Theme.quickTextDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                text: root.message.length > 0
                      ? root.message
                      : "Экземпляры с выбранным «По умолчанию» следуют этим значениям."
            }

            Item { width: 1; height: Math.max(0, parent.height - 430) }

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
