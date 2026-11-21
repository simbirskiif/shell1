pragma ComponentBehavior: Bound

import QtQuick
import "../../components/quick"
import "../../components/expressive"
import "../../singletons"
import "../core"

// Глобальные параметры виджетов (материал и режим цвета по умолчанию).
// Это тот же слой/окно рабочего стола, отдельного окна настроек нет.
//
// Expressive: шапка с крупным заголовком, секции — emphasized-подписи,
// материал/цвет — пилюли 40 (активная — tertiary-контейнер с формой
// «печенье»), действия — пилюли 48. Тонких разделителей нет: секции
// разделяются воздухом и цветом контейнеров.
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

    // Содержимое прокручивается, чтобы футер с «Закрыть» не уезжал за
    // нижнюю границу экрана (раньше это был Column на всю высоту панели).
    Flickable {
        id: contentScroll

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.space.sm
        clip: true
        contentHeight: contentColumn.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn

            width: contentScroll.width
            spacing: Theme.space.md

            // Шапка — Expressive top app bar: крупный заголовок, icon-кнопка.
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
                    text: "Параметры виджетов"
                }

                HostIconButton {
                    id: headerClose

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    onClicked: EditorState.closeGlobalSettings()
                }
            }

            Text {
                width: parent.width
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodyMedium
                wrapMode: Text.WordWrap
                text: "Действуют для всех виджетов, пока экземпляр не переопределил "
                      + "материал или цвет в своих настройках."
            }

            Text {
                topPadding: Theme.space.xs
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedLabelLarge
                text: "Материал по умолчанию"
            }

            Flow {
                width: parent.width
                spacing: Theme.space.sm

                Repeater {
                    model: MaterialRegistry.materials

                    delegate: HostButton {
                        required property var modelData

                        text: modelData.name
                        height: 40
                        active: Config.defaultMaterial === modelData.id
                        onClicked: root.chooseMaterial(modelData.id)
                    }
                }
            }

            Text {
                topPadding: Theme.space.xs
                color: Theme.scheme.onSurface
                font: Theme.typeEmphasizedLabelLarge
                text: "Цвет по умолчанию"
            }

            Flow {
                width: parent.width
                spacing: Theme.space.sm

                HostButton {
                    text: "Акцент"
                    height: 40
                    active: Config.defaultColorMode === "accent"
                    onClicked: root.chooseColorMode("accent")
                }

                HostButton {
                    text: "Нейтральная"
                    height: 40
                    active: Config.defaultColorMode === "neutral"
                    onClicked: root.chooseColorMode("neutral")
                }
            }

            Text {
                topPadding: Theme.space.xs
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
                    value: Config.defaultMaterialDim
                    onMoved: value => Config.setDefaultMaterialDim(value)
                }

                Text {
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    color: Theme.tertiary
                    font: Theme.typeEmphasizedLabelLarge
                    text: Math.round(Config.defaultMaterialDim * 100) + "%"
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: root.message.length > 0
                       ? Theme.tertiary
                       : Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                text: root.message.length > 0
                      ? root.message
                      : "Экземпляры с выбранным «По умолчанию» следуют этим значениям."
            }
        }
    }

    // Футер закреплён внизу и виден всегда: Expressive-пилюли 48,
    // действия у краёв.
    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 48

        HostButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Сбросить переопределения"
            height: 48
            onClicked: {
                EditorState.beginOperation()
                const count = LayoutStore.clearOverrides()
                root.message = count > 0
                             ? "Сброшено переопределений: " + count
                             : "Переопределений нет"
            }
        }

        HostButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Закрыть"
            height: 48
            prominent: true
            onClicked: EditorState.closeGlobalSettings()
        }
    }
}
