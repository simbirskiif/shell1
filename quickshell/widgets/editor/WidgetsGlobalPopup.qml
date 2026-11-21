pragma ComponentBehavior: Bound

import QtQuick
import "../../components/quick"
import "../../singletons"
import "../core"

// Глобальные параметры виджетов (материал и режим цвета по умолчанию).
// Это тот же слой/окно рабочего стола, отдельного окна настроек нет.
//
// Оформление — M3: шапка как top app bar (titleLarge + иконка 40), секции
// подписаны labelLarge, выбор материала/цвета — filter chips 32, действия —
// пилюли 40 px. Поверхность панели даёт SidePanel.
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
                    text: "Параметры виджетов"
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
                        onClicked: EditorState.closeGlobalSettings()
                    }
                }
            }

            Text {
                width: parent.width
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WordWrap
                text: "Действуют для всех виджетов, пока экземпляр не переопределил "
                      + "материал или цвет в своих настройках."
            }

            Text {
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
                text: "Материал по умолчанию"
            }

            Flow {
                width: parent.width
                spacing: Theme.space.sm

                Repeater {
                    model: MaterialRegistry.materials

                    delegate: Rectangle {
                        id: materialChip

                        required property var modelData

                        readonly property bool selected:
                            Config.defaultMaterial === materialChip.modelData.id

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
                            text: materialChip.modelData.name
                            color: materialChip.selected
                                   ? Theme.scheme.onSecondaryContainer
                                   : Theme.scheme.onSurfaceVariant
                            font: Theme.typeLabelLarge
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.stateLayer(
                                       materialChip.selected
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
                            onClicked: root.chooseMaterial(materialChip.modelData.id)
                        }
                    }
                }
            }

            Text {
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
                text: "Цвет по умолчанию"
            }

            Row {
                spacing: Theme.space.sm

                Rectangle {
                    id: accentChip

                    readonly property bool selected:
                        Config.defaultColorMode === "accent"

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
                        text: "Акцент"
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
                        onClicked: root.chooseColorMode("accent")
                    }
                }

                Rectangle {
                    id: neutralChip

                    readonly property bool selected:
                        Config.defaultColorMode === "neutral"

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
                        text: "Нейтральная"
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
                        onClicked: root.chooseColorMode("neutral")
                    }
                }
            }

            Text {
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeLabelLarge
                text: "Затемнение материала"
            }

            Row {
                width: parent.width
                spacing: Theme.space.sm

                PanelSlider {
                    width: Math.max(80, parent.width - 48)
                    value: Config.defaultMaterialDim
                    onMoved: value => Config.setDefaultMaterialDim(value)
                }

                Text {
                    width: 40
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    color: Theme.scheme.onSurfaceVariant
                    font: Theme.typeLabelMedium
                    text: Math.round(Config.defaultMaterialDim * 100) + "%"
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineVariant
            }

            Text {
                width: parent.width
                color: Theme.scheme.onSurfaceVariant
                font: Theme.typeBodySmall
                wrapMode: Text.WordWrap
                text: root.message.length > 0
                      ? root.message
                      : "Экземпляры с выбранным «По умолчанию» следуют этим значениям."
            }
        }
    }

    // Футер закреплён внизу и виден всегда: M3-пилюли, действия у краёв.
    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.buttonHeight

        Rectangle {
            id: resetAction

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: resetActionLabel.implicitWidth + Theme.space.xl * 2
            height: Theme.buttonHeight
            radius: Theme.shape.full
            color: "transparent"

            Text {
                id: resetActionLabel

                anchors.centerIn: parent
                text: "Сбросить переопределения"
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
                onClicked: {
                    EditorState.beginOperation()
                    const count = LayoutStore.clearOverrides()
                    root.message = count > 0
                                 ? "Сброшено переопределений: " + count
                                 : "Переопределений нет"
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
                text: "Закрыть"
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
                onClicked: EditorState.closeGlobalSettings()
            }
        }
    }
}
